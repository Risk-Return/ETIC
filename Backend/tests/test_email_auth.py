"""邮箱验证码登录测试：验证码生成/哈希、DB 操作、API 端点。

DB/API 测试需要 Postgres（同账号测试），不可用时跳过。
"""

import time
import uuid
from unittest.mock import AsyncMock, patch

import httpx
import psycopg
import pytest
from asgi_lifespan import LifespanManager

from app.account_db import (
    create_email_code,
    ensure_schema,
    get_or_create_user,
    get_or_create_user_by_email,
    latest_email_code_created_at,
    verify_and_consume_email_code,
)
from app.config import Settings, get_settings
from app.email_auth import generate_code, hash_code, is_valid_email
from app.main import app

DEFAULT_DB_URL = "postgresql://etic:etic@localhost:5432/etic"


def _settings() -> Settings:
    return Settings(
        mock_llm=True,
        billing_enabled=True,
        jwt_secret="test-secret",
        free_monthly_credits=3,
        database_url=DEFAULT_DB_URL,
        email_code_cooldown_seconds=60,
        email_code_ttl_minutes=10,
        email_code_max_attempts=5,
    )


@pytest.fixture
def db_conn():
    settings = _settings()
    try:
        conn = psycopg.connect(settings.database_url)
        ensure_schema(conn)
        yield conn
        conn.execute("DELETE FROM users WHERE email LIKE 'emailtest-%'")
        conn.execute(
            "DELETE FROM users WHERE apple_user_identifier LIKE 'apple-emailtest-%'"
        )
        conn.execute("DELETE FROM email_verification_codes WHERE email LIKE 'emailtest-%'")
        conn.commit()
        conn.close()
    except psycopg.OperationalError as exc:
        pytest.skip(f"Postgres not available: {exc}")


@pytest.fixture
def email_settings(monkeypatch):
    get_settings.cache_clear()
    monkeypatch.setenv("ETIC_MOCK_LLM", "true")
    monkeypatch.setenv("ETIC_RAG_ENABLED", "false")
    monkeypatch.setenv("ETIC_BILLING_ENABLED", "true")
    monkeypatch.setenv("ETIC_JWT_SECRET", "test-secret")
    monkeypatch.setenv("ETIC_DATABASE_URL", DEFAULT_DB_URL)
    monkeypatch.setenv("ETIC_SMTP_USER", "")
    monkeypatch.setenv("ETIC_SMTP_PASSWORD", "")
    yield
    get_settings.cache_clear()


@pytest.fixture
async def client(email_settings):
    async with LifespanManager(app):
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as c:
            yield c


# ---- Unit tests (no DB) ----


def test_is_valid_email():
    assert is_valid_email("a@b.com")
    assert is_valid_email("user.name+tag@example.co.uk")
    assert not is_valid_email("not-an-email")
    assert not is_valid_email("a@b")
    assert not is_valid_email("a b@c.com")
    assert not is_valid_email("")


def test_generate_code_format():
    for _ in range(20):
        code = generate_code()
        assert len(code) == 6
        assert code.isdigit()


def test_hash_code_deterministic():
    settings = _settings()
    h1 = hash_code("A@B.com", "123456", settings)
    h2 = hash_code("a@b.com", "123456", settings)
    assert h1 == h2  # email normalized
    assert h1 != hash_code("a@b.com", "654321", settings)


# ---- DB operation tests ----


def test_get_or_create_user_by_email(db_conn):
    email = "emailtest-1@example.com"
    user_id, created = get_or_create_user_by_email(db_conn, email, free_credits=3)
    assert created
    assert isinstance(user_id, uuid.UUID)

    # Same email (different case) returns same user.
    user_id2, created2 = get_or_create_user_by_email(db_conn, "Emailtest-1@Example.COM")
    assert not created2
    assert user_id2 == user_id


def test_email_user_reused_by_apple_sign_in(db_conn):
    """邮箱注册后再用 Apple 登录（同邮箱）应复用同一账号。"""
    email = "emailtest-2@example.com"
    user_id, _ = get_or_create_user_by_email(db_conn, email, free_credits=3)

    apple_id, created = get_or_create_user(
        db_conn, "apple-emailtest-sub-2", email, "Name"
    )
    assert not created
    assert apple_id == user_id


def test_apple_user_reused_by_email_sign_in(db_conn):
    """Apple 登录（带邮箱）后再用邮箱验证码登录应复用同一账号。"""
    email = "emailtest-3@example.com"
    apple_id, _ = get_or_create_user(db_conn, "apple-emailtest-sub-3", email)

    user_id, created = get_or_create_user_by_email(db_conn, email)
    assert not created
    assert user_id == apple_id


def test_email_code_verify_and_consume(db_conn):
    settings = _settings()
    email = "emailtest-4@example.com"
    code = "123456"
    create_email_code(db_conn, email, hash_code(email, code, settings), 10)

    assert latest_email_code_created_at(db_conn, email) is not None

    # Wrong code fails, right code succeeds, reuse fails.
    assert not verify_and_consume_email_code(
        db_conn, email, hash_code(email, "000000", settings), 5
    )
    assert verify_and_consume_email_code(
        db_conn, email, hash_code(email, code, settings), 5
    )
    assert not verify_and_consume_email_code(
        db_conn, email, hash_code(email, code, settings), 5
    )


def test_email_code_max_attempts(db_conn):
    settings = _settings()
    email = "emailtest-5@example.com"
    code = "123456"
    create_email_code(db_conn, email, hash_code(email, code, settings), 10)

    for _ in range(5):
        assert not verify_and_consume_email_code(
            db_conn, email, hash_code(email, "000000", settings), 5
        )
    # Attempts exhausted — even the right code now fails.
    assert not verify_and_consume_email_code(
        db_conn, email, hash_code(email, code, settings), 5
    )


def test_email_code_new_code_invalidates_old(db_conn):
    settings = _settings()
    email = "emailtest-6@example.com"
    create_email_code(db_conn, email, hash_code(email, "111111", settings), 10)
    create_email_code(db_conn, email, hash_code(email, "222222", settings), 10)

    assert not verify_and_consume_email_code(
        db_conn, email, hash_code(email, "111111", settings), 5
    )
    # Note: the failed attempt above counted against the active code.
    assert verify_and_consume_email_code(
        db_conn, email, hash_code(email, "222222", settings), 5
    )


# ---- API endpoint tests ----


@pytest.mark.asyncio
async def test_request_code_invalid_email(client):
    resp = await client.post("/v1/auth/email/code", json={"email": "bad"})
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_email_sign_in_flow(client, db_conn):
    """请求验证码（mock SMTP，捕获验证码）→ 验证 → 拿到会话令牌。"""
    email = f"emailtest-flow-{int(time.time())}@example.com"
    captured = {}

    async def fake_send(to_email, code, settings):
        captured["code"] = code

    with patch("app.account.send_verification_email", new=AsyncMock(side_effect=fake_send)):
        resp = await client.post("/v1/auth/email/code", json={"email": email})
    assert resp.status_code == 200
    assert resp.json()["success"]
    assert "code" in captured

    resp = await client.post(
        "/v1/auth/email/verify", json={"email": email, "code": captured["code"]}
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "sessionToken" in body
    assert body["account"]["userId"]
    assert body["account"]["freeCredits"] == 3

    # Session token works for /v1/account/me.
    resp = await client.get(
        "/v1/account/me",
        headers={"Authorization": f"Bearer {body['sessionToken']}"},
    )
    assert resp.status_code == 200
    assert resp.json()["userId"] == body["account"]["userId"]


@pytest.mark.asyncio
async def test_email_verify_wrong_code(client, db_conn):
    email = f"emailtest-wrong-{int(time.time())}@example.com"
    with patch("app.account.send_verification_email", new=AsyncMock()):
        resp = await client.post("/v1/auth/email/code", json={"email": email})
    assert resp.status_code == 200

    resp = await client.post(
        "/v1/auth/email/verify", json={"email": email, "code": "000000"}
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_request_code_cooldown(client, db_conn):
    email = f"emailtest-cd-{int(time.time())}@example.com"
    with patch("app.account.send_verification_email", new=AsyncMock()):
        resp = await client.post("/v1/auth/email/code", json={"email": email})
        assert resp.status_code == 200
        resp = await client.post("/v1/auth/email/code", json={"email": email})
    assert resp.status_code == 429
