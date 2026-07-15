"""账号 & 计费数据库：建表与 CRUD。

表结构：
- users               — Apple Sign In / 邮箱验证码 用户
- credit_balances     — 免费/付费解读额度
- transactions        — 充值/订阅/消费流水
- subscriptions       — 订阅状态
- readings            — 每次解读的追问计数
- email_verification_codes — 邮箱登录验证码（哈希存储）

所有写入操作在调用方管理的事务内完成。
"""

from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from typing import Optional

import psycopg

from .config import Settings

# ---- DDL ----

_SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS users (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apple_user_identifier TEXT UNIQUE,
    email                TEXT,
    name                 TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS credit_balances (
    user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    free_credits         INT  NOT NULL DEFAULT 0,
    paid_credits         INT  NOT NULL DEFAULT 0,
    free_reset_at        DATE NOT NULL DEFAULT CURRENT_DATE,
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id)
);

CREATE TABLE IF NOT EXISTS transactions (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type                 TEXT NOT NULL,
    product_id           TEXT,
    credits              INT  NOT NULL DEFAULT 0,
    amount_cents         INT,
    original_transaction_id TEXT,
    environment          TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subscriptions (
    user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id           TEXT NOT NULL,
    status               TEXT NOT NULL DEFAULT 'active',
    original_transaction_id TEXT,
    expires_at           TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id)
);

CREATE TABLE IF NOT EXISTS readings (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    board_key            TEXT NOT NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    questions_asked      INT  NOT NULL DEFAULT 0,
    UNIQUE (user_id, board_key)
);

CREATE TABLE IF NOT EXISTS email_verification_codes (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email                TEXT NOT NULL,
    code_hash            TEXT NOT NULL,
    expires_at           TIMESTAMPTZ NOT NULL,
    attempts             INT  NOT NULL DEFAULT 0,
    consumed_at          TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS transactions_user_idx ON transactions (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS email_codes_email_idx ON email_verification_codes (email, created_at DESC);
"""

# 兼容既有生产库的增量迁移（逐条执行、失败忽略，保证幂等）。
_MIGRATION_SQL = [
    "ALTER TABLE users ALTER COLUMN apple_user_identifier DROP NOT NULL",
]


def ensure_schema(conn: psycopg.Connection) -> None:
    with conn.cursor() as cur:
        cur.execute(_SCHEMA_SQL)
    conn.commit()
    for stmt in _MIGRATION_SQL:
        try:
            with conn.cursor() as cur:
                cur.execute(stmt)
            conn.commit()
        except psycopg.Error:
            conn.rollback()


# ---- Helpers ----


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _current_month_start() -> date:
    return date.today().replace(day=1)


def _maybe_reset_free_credits(cur: psycopg.Cursor, user_id: uuid.UUID, settings: Settings) -> None:
    """If the calendar month has changed since last reset, top up free credits."""
    month_start = _current_month_start()
    cur.execute(
        "SELECT free_reset_at FROM credit_balances WHERE user_id = %s",
        (user_id,),
    )
    row = cur.fetchone()
    if row is None:
        return
    last_reset = row[0]
    if last_reset < month_start:
        cur.execute(
            "UPDATE credit_balances SET free_credits = %s, free_reset_at = %s, updated_at = NOW() "
            "WHERE user_id = %s",
            (settings.free_monthly_credits, month_start, user_id),
        )


# ---- User operations ----


def get_or_create_user(
    conn: psycopg.Connection,
    apple_sub: str,
    email: Optional[str] = None,
    name: Optional[str] = None,
    free_credits: int = 0,
) -> tuple[uuid.UUID, bool]:
    """Return (user_id, created). On first create, initializes credit balance."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM users WHERE apple_user_identifier = %s",
            (apple_sub,),
        )
        row = cur.fetchone()
        if row is not None:
            user_id = row[0]
            # Update email/name if provided and different.
            if email or name:
                cur.execute(
                    "UPDATE users SET email = COALESCE(%s, email), "
                    "name = COALESCE(%s, name), updated_at = NOW() WHERE id = %s",
                    (email, name, user_id),
                )
            conn.commit()
            return user_id, False

        # 若已有同邮箱的"仅邮箱"账号（无 apple_sub），将 Apple 身份绑定到该账号，
        # 避免同一用户经邮箱与 Apple 两条路径产生两个账号。
        if email:
            cur.execute(
                "SELECT id FROM users WHERE apple_user_identifier IS NULL "
                "AND LOWER(email) = LOWER(%s) ORDER BY created_at LIMIT 1",
                (email,),
            )
            row = cur.fetchone()
            if row is not None:
                user_id = row[0]
                cur.execute(
                    "UPDATE users SET apple_user_identifier = %s, "
                    "name = COALESCE(%s, name), updated_at = NOW() WHERE id = %s",
                    (apple_sub, name, user_id),
                )
                conn.commit()
                return user_id, False

        user_id = uuid.uuid4()
        cur.execute(
            "INSERT INTO users (id, apple_user_identifier, email, name) "
            "VALUES (%s, %s, %s, %s)",
            (user_id, apple_sub, email, name),
        )
        cur.execute(
            "INSERT INTO credit_balances (user_id, free_credits, free_reset_at) "
            "VALUES (%s, %s, %s)",
            (user_id, free_credits, _current_month_start()),
        )
        conn.commit()
        return user_id, True


def get_or_create_user_by_email(
    conn: psycopg.Connection,
    email: str,
    free_credits: int = 0,
) -> tuple[uuid.UUID, bool]:
    """邮箱验证码登录：按邮箱（不区分大小写）检索或创建用户。

    优先复用已有账号（含 Apple 登录时留下邮箱的账号），保证同一邮箱只有一个账号，
    额度与订阅在两种登录方式间共享。
    """
    email_norm = email.strip().lower()
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM users WHERE LOWER(email) = %s ORDER BY created_at LIMIT 1",
            (email_norm,),
        )
        row = cur.fetchone()
        if row is not None:
            conn.commit()
            return row[0], False

        user_id = uuid.uuid4()
        cur.execute(
            "INSERT INTO users (id, email) VALUES (%s, %s)",
            (user_id, email_norm),
        )
        cur.execute(
            "INSERT INTO credit_balances (user_id, free_credits, free_reset_at) "
            "VALUES (%s, %s, %s)",
            (user_id, free_credits, _current_month_start()),
        )
        conn.commit()
        return user_id, True


def get_user_by_id(conn: psycopg.Connection, user_id: uuid.UUID) -> Optional[dict]:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id, apple_user_identifier, email, name, created_at "
            "FROM users WHERE id = %s",
            (user_id,),
        )
        row = cur.fetchone()
        if row is None:
            return None
        return {
            "id": row[0],
            "apple_user_identifier": row[1],
            "email": row[2],
            "name": row[3],
            "created_at": row[4],
        }


# ---- Email verification code operations ----


def latest_email_code_created_at(
    conn: psycopg.Connection, email: str
) -> Optional[datetime]:
    """Return created_at of the most recent code for this email (for cooldown)."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT created_at FROM email_verification_codes "
            "WHERE email = %s ORDER BY created_at DESC LIMIT 1",
            (email.strip().lower(),),
        )
        row = cur.fetchone()
        return row[0] if row else None


def create_email_code(
    conn: psycopg.Connection, email: str, code_hash: str, ttl_minutes: int
) -> None:
    """Store a new verification code (hashed); invalidates prior unconsumed codes."""
    email_norm = email.strip().lower()
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE email_verification_codes SET consumed_at = NOW() "
            "WHERE email = %s AND consumed_at IS NULL",
            (email_norm,),
        )
        cur.execute(
            "INSERT INTO email_verification_codes (email, code_hash, expires_at) "
            "VALUES (%s, %s, NOW() + %s * INTERVAL '1 minute')",
            (email_norm, code_hash, ttl_minutes),
        )
        cur.execute(
            "DELETE FROM email_verification_codes WHERE created_at < NOW() - INTERVAL '1 day'"
        )
    conn.commit()


def verify_and_consume_email_code(
    conn: psycopg.Connection, email: str, code_hash: str, max_attempts: int
) -> bool:
    """Check the latest active code for this email. Consumes it on success.

    Wrong attempts are counted; the code is dead after max_attempts failures.
    """
    email_norm = email.strip().lower()
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id, code_hash, attempts FROM email_verification_codes "
            "WHERE email = %s AND consumed_at IS NULL AND expires_at > NOW() "
            "ORDER BY created_at DESC LIMIT 1 FOR UPDATE",
            (email_norm,),
        )
        row = cur.fetchone()
        if row is None:
            conn.commit()
            return False
        code_id, stored_hash, attempts = row
        if attempts >= max_attempts:
            conn.commit()
            return False
        if stored_hash != code_hash:
            cur.execute(
                "UPDATE email_verification_codes SET attempts = attempts + 1 WHERE id = %s",
                (code_id,),
            )
            conn.commit()
            return False
        cur.execute(
            "UPDATE email_verification_codes SET consumed_at = NOW() WHERE id = %s",
            (code_id,),
        )
    conn.commit()
    return True


# ---- Credit operations ----


def get_account_status(
    conn: psycopg.Connection, user_id: uuid.UUID, settings: Settings
) -> dict:
    """Return account status: credits, subscription, etc."""
    with conn.cursor() as cur:
        _maybe_reset_free_credits(cur, user_id, settings)

        cur.execute(
            "SELECT free_credits, paid_credits, free_reset_at FROM credit_balances WHERE user_id = %s",
            (user_id,),
        )
        bal = cur.fetchone()
        free_credits = bal[0] if bal else 0
        paid_credits = bal[1] if bal else 0

        cur.execute(
            "SELECT product_id, status, expires_at FROM subscriptions WHERE user_id = %s",
            (user_id,),
        )
        sub = cur.fetchone()
        subscription = None
        if sub is not None:
            subscription = {
                "productId": sub[0],
                "status": sub[1],
                "expiresAt": sub[2].isoformat() if sub[2] else None,
            }

    return {
        "userId": str(user_id),
        "freeCredits": free_credits,
        "paidCredits": paid_credits,
        "totalCredits": free_credits + paid_credits,
        "freeMonthlyCredits": settings.free_monthly_credits,
        "maxQuestionsPerReading": settings.max_questions_per_reading,
        "subscription": subscription,
    }


def has_active_subscription(conn: psycopg.Connection, user_id: uuid.UUID) -> bool:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT status, expires_at FROM subscriptions WHERE user_id = %s",
            (user_id,),
        )
        row = cur.fetchone()
        if row is None:
            return False
        status, expires_at = row
        if status != "active":
            return False
        if expires_at and expires_at < _now():
            return False
        return True


def deduct_credit(
    conn: psycopg.Connection, user_id: uuid.UUID, settings: Settings
) -> bool:
    """Deduct one credit. Free credits first, then paid. Returns True on success."""
    with conn.cursor() as cur:
        _maybe_reset_free_credits(cur, user_id, settings)
        cur.execute(
            "SELECT free_credits, paid_credits FROM credit_balances WHERE user_id = %s FOR UPDATE",
            (user_id,),
        )
        row = cur.fetchone()
        if row is None:
            return False
        free_c, paid_c = row
        if free_c > 0:
            cur.execute(
                "UPDATE credit_balances SET free_credits = free_credits - 1, updated_at = NOW() "
                "WHERE user_id = %s",
                (user_id,),
            )
        elif paid_c > 0:
            cur.execute(
                "UPDATE credit_balances SET paid_credits = paid_credits - 1, updated_at = NOW() "
                "WHERE user_id = %s",
                (user_id,),
            )
        else:
            return False
        cur.execute(
            "INSERT INTO transactions (user_id, type, credits) VALUES (%s, 'usage', -1)",
            (user_id,),
        )
    conn.commit()
    return True


def add_paid_credits(
    conn: psycopg.Connection,
    user_id: uuid.UUID,
    credits: int,
    product_id: str,
    original_transaction_id: Optional[str] = None,
    amount_cents: Optional[int] = None,
    environment: Optional[str] = None,
) -> None:
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE credit_balances SET paid_credits = paid_credits + %s, updated_at = NOW() "
            "WHERE user_id = %s",
            (credits, user_id),
        )
        cur.execute(
            "INSERT INTO transactions (user_id, type, product_id, credits, amount_cents, original_transaction_id, environment) "
            "VALUES (%s, 'topup', %s, %s, %s, %s, %s)",
            (user_id, product_id, credits, amount_cents, original_transaction_id, environment),
        )
    conn.commit()


def get_subscription_by_tx(
    conn: psycopg.Connection, original_transaction_id: str
) -> Optional[str]:
    """Return user_id (as string) for a given original transaction ID, or None."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT user_id FROM subscriptions WHERE original_transaction_id = %s",
            (original_transaction_id,),
        )
        row = cur.fetchone()
        return str(row[0]) if row else None


def get_subscription(
    conn: psycopg.Connection, user_id: uuid.UUID
) -> Optional[dict]:
    """Return subscription row for a user, or None."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT product_id, status, original_transaction_id, expires_at "
            "FROM subscriptions WHERE user_id = %s",
            (user_id,),
        )
        row = cur.fetchone()
        if row is None:
            return None
        return {
            "product_id": row[0],
            "status": row[1],
            "original_transaction_id": row[2],
            "expires_at": row[3],
        }


def activate_subscription(
    conn: psycopg.Connection,
    user_id: uuid.UUID,
    product_id: str,
    original_transaction_id: Optional[str] = None,
    expires_at: Optional[datetime] = None,
    environment: Optional[str] = None,
) -> None:
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO subscriptions (user_id, product_id, status, original_transaction_id, expires_at) "
            "VALUES (%s, %s, 'active', %s, %s) "
            "ON CONFLICT (user_id) DO UPDATE SET "
            "product_id = EXCLUDED.product_id, status = 'active', "
            "original_transaction_id = EXCLUDED.original_transaction_id, "
            "expires_at = EXCLUDED.expires_at, updated_at = NOW()",
            (user_id, product_id, original_transaction_id, expires_at),
        )
    conn.commit()


# ---- Reading operations ----


def get_or_create_reading(
    conn: psycopg.Connection, user_id: uuid.UUID, board_key: str
) -> tuple[uuid.UUID, bool]:
    """Return (reading_id, created). Deduct credit only on creation (caller handles)."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM readings WHERE user_id = %s AND board_key = %s",
            (user_id, board_key),
        )
        row = cur.fetchone()
        if row is not None:
            return row[0], False
        reading_id = uuid.uuid4()
        cur.execute(
            "INSERT INTO readings (id, user_id, board_key) VALUES (%s, %s, %s)",
            (reading_id, user_id, board_key),
        )
        conn.commit()
        return reading_id, True


def increment_reading_questions(
    conn: psycopg.Connection,
    user_id: uuid.UUID,
    board_key: str,
    settings: Settings,
) -> bool:
    """Increment question count for a reading. Returns False if limit exceeded."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id, questions_asked FROM readings WHERE user_id = %s AND board_key = %s FOR UPDATE",
            (user_id, board_key),
        )
        row = cur.fetchone()
        if row is None:
            return False
        reading_id, asked = row
        if asked >= settings.max_questions_per_reading:
            return False
        cur.execute(
            "UPDATE readings SET questions_asked = questions_asked + 1 WHERE id = %s",
            (reading_id,),
        )
    conn.commit()
    return True


def get_reading_questions_asked(
    conn: psycopg.Connection, user_id: uuid.UUID, board_key: str
) -> int:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT questions_asked FROM readings WHERE user_id = %s AND board_key = %s",
            (user_id, board_key),
        )
        row = cur.fetchone()
        return row[0] if row else 0
