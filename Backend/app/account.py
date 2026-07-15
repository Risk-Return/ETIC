"""账号 & 计费路由：Apple Sign In、邮箱验证码登录、账号状态、IAP 验证。

所有端点前缀 `/v1`，与解读端点同级。
"""

from __future__ import annotations

import base64
import json
import logging
import uuid
from datetime import datetime, timedelta, timezone

import jwt as pyjwt
from fastapi import APIRouter, Depends, HTTPException

from .account_db import (
    activate_subscription,
    add_paid_credits,
    create_email_code,
    deduct_credit,
    ensure_schema,
    get_account_status,
    get_or_create_reading,
    get_or_create_user,
    get_or_create_user_by_email,
    get_subscription,
    increment_reading_questions,
    latest_email_code_created_at,
    verify_and_consume_email_code,
)
from .account_models import (
    AccountStatus,
    AppleAuthRequest,
    AuthResponse,
    EmailCodeRequest,
    EmailCodeResponse,
    EmailVerifyRequest,
    IAPVerifyRequest,
    IAPVerifyResponse,
)
from .auth import (
    get_or_create_user_from_apple,
    issue_session_jwt,
    require_user_id,
    verify_apple_identity_token,
)
from .config import Settings, get_settings
from .db import connect
from .email_auth import (
    generate_code,
    hash_code,
    is_valid_email,
    send_verification_email,
)

logger = logging.getLogger("etic.account")

router = APIRouter(prefix="/v1", tags=["Account"])


def _ensure_db(settings: Settings) -> None:
    with connect(settings) as conn:
        ensure_schema(conn)


def _account_status(settings: Settings, user_id: uuid.UUID) -> AccountStatus:
    with connect(settings) as conn:
        data = get_account_status(conn, user_id, settings)
    return AccountStatus(**data)


@router.post("/auth/apple", response_model=AuthResponse)
async def apple_sign_in(
    req: AppleAuthRequest,
    settings: Settings = Depends(get_settings),
) -> AuthResponse:
    """Apple Sign In：验签 identity token → 创建/检索用户 → 签发会话 JWT。"""

    try:
        claims = await verify_apple_identity_token(req.identityToken, settings)
    except Exception as exc:
        logger.warning("Apple identity token verification failed: %s", exc)
        raise HTTPException(status_code=401, detail="Apple identity token verification failed")

    apple_sub = claims.get("sub")
    if not apple_sub:
        raise HTTPException(status_code=401, detail="Apple identity token missing sub claim")

    email = req.email or claims.get("email")
    name = req.fullName

    _ensure_db(settings)
    user_id, created = get_or_create_user_from_apple(settings, apple_sub, email, name)
    session_token = issue_session_jwt(user_id, settings)
    account = _account_status(settings, user_id)

    logger.info("Apple Sign In | user=%s created=%s", user_id, created)
    return AuthResponse(sessionToken=session_token, account=account)


@router.post("/auth/email/code", response_model=EmailCodeResponse)
async def request_email_code(
    req: EmailCodeRequest,
    settings: Settings = Depends(get_settings),
) -> EmailCodeResponse:
    """发送邮箱登录验证码：校验邮箱 → 冷却检查 → 生成并哈希入库 → SMTP 发信。

    为防枚举，不区分邮箱是否已注册，一律发送验证码。
    """

    email = req.email.strip().lower()
    if not is_valid_email(email):
        raise HTTPException(status_code=400, detail="Invalid email address")

    _ensure_db(settings)
    cooldown = settings.email_code_cooldown_seconds
    with connect(settings) as conn:
        last = latest_email_code_created_at(conn, email)
        if last is not None:
            elapsed = (datetime.now(timezone.utc) - last).total_seconds()
            if elapsed < cooldown:
                raise HTTPException(
                    status_code=429,
                    detail=f"Please wait {int(cooldown - elapsed)}s before requesting a new code",
                )

    code = generate_code()
    try:
        await send_verification_email(email, code, settings)
    except Exception as exc:
        logger.error("Failed to send verification email to %s: %s", email, exc)
        raise HTTPException(status_code=502, detail="Failed to send verification email")

    with connect(settings) as conn:
        create_email_code(
            conn, email, hash_code(email, code, settings), settings.email_code_ttl_minutes
        )

    logger.info("Email code issued | email=%s", email)
    return EmailCodeResponse(
        success=True, cooldownSeconds=cooldown, message="Verification code sent"
    )


@router.post("/auth/email/verify", response_model=AuthResponse)
async def email_sign_in(
    req: EmailVerifyRequest,
    settings: Settings = Depends(get_settings),
) -> AuthResponse:
    """邮箱验证码登录：校验验证码 → 创建/检索用户 → 签发会话 JWT。"""

    email = req.email.strip().lower()
    code = req.code.strip()
    if not is_valid_email(email) or not code:
        raise HTTPException(status_code=400, detail="Invalid email or code")

    _ensure_db(settings)
    with connect(settings) as conn:
        ok = verify_and_consume_email_code(
            conn, email, hash_code(email, code, settings), settings.email_code_max_attempts
        )
        if not ok:
            raise HTTPException(status_code=401, detail="Invalid or expired verification code")
        user_id, created = get_or_create_user_by_email(
            conn, email, settings.free_monthly_credits
        )

    session_token = issue_session_jwt(user_id, settings)
    account = _account_status(settings, user_id)

    logger.info("Email Sign In | user=%s created=%s", user_id, created)
    return AuthResponse(sessionToken=session_token, account=account)


@router.post("/auth/test", response_model=AuthResponse)
async def test_sign_in(
    settings: Settings = Depends(get_settings),
) -> AuthResponse:
    """开发模式测试登录：跳过 Apple 验签，直接创建/检索测试用户。

    仅在 ETIC_DEV_MODE=true 时可用，生产环境返回 403。
    """

    if not settings.dev_mode:
        raise HTTPException(status_code=403, detail="Test login is disabled")

    _ensure_db(settings)
    test_apple_sub = "test-user-local-dev"
    user_id, created = get_or_create_user_from_apple(
        settings, test_apple_sub, "test@etic.local", "Test User"
    )
    session_token = issue_session_jwt(user_id, settings)
    account = _account_status(settings, user_id)

    logger.info("Test Sign In | user=%s created=%s", user_id, created)
    return AuthResponse(sessionToken=session_token, account=account)


@router.get("/account/me", response_model=AccountStatus)
async def get_my_account(
    user_id: uuid.UUID = Depends(require_user_id),
    settings: Settings = Depends(get_settings),
) -> AccountStatus:
    """获取当前用户账号状态（额度、订阅、限额）。"""

    _ensure_db(settings)
    return _account_status(settings, user_id)


@router.post("/iap/verify", response_model=IAPVerifyResponse)
async def verify_iap(
    req: IAPVerifyRequest,
    user_id: uuid.UUID = Depends(require_user_id),
    settings: Settings = Depends(get_settings),
) -> IAPVerifyResponse:
    """验证 StoreKit 2 交易并发放额度/激活订阅。

    iOS 端购买完成后，将 `Transaction.jwsRepresentation` 提交至此。
    当前阶段：解码 JWS 取出交易信息（生产环境需用 Apple 根证书完整验签）。
    """

    _ensure_db(settings)

    # Decode JWS payload (unverified — production should verify with Apple certs).
    try:
        unverified = pyjwt.decode(req.jwsRepresentation, options={"verify_signature": False})
    except Exception:
        # JWT decode failed — client may be sending base64(jsonRepresentation)
        # instead of jwsRepresentation. Attempt to parse as base64-encoded JSON.
        unverified = {}
        try:
            raw = base64.b64decode(req.jwsRepresentation)
            unverified = json.loads(raw.decode("utf-8"))
            logger.warning(
                "IAP verify | JWT decode failed, fell back to base64 JSON parse | user=%s",
                user_id,
            )
        except Exception:
            pass

    product_id = req.productId
    original_tx_id = req.originalTransactionId or str(
        unverified.get("originalTransactionId", "")
    )
    environment = unverified.get("environment", "Unknown")
    # Normalize Apple's values: "Sandbox" or "Production"
    if isinstance(environment, str):
        environment = environment.capitalize()

    logger.info(
        "IAP verify | user=%s product=%s environment=%s originalTx=%s",
        user_id, product_id, environment, original_tx_id,
    )

    # Check if it's a subscription or top-up.
    if product_id == settings.subscription_product_id:
        # Activate subscription. StoreKit auto-renewable subscriptions have
        # expiresTime in ms since epoch.
        expires_ms = unverified.get("expiresTime")
        expires_at = None
        if expires_ms:
            expires_at = datetime.fromtimestamp(expires_ms / 1000, tz=timezone.utc)
        elif unverified.get("type") == "Auto-Renewable Subscription":
            expires_at = datetime.now(timezone.utc) + timedelta(days=30)

        with connect(settings) as conn:
            ensure_schema(conn)
            existing_sub = get_subscription(conn, user_id)
            is_new_purchase = (
                existing_sub is None
                or existing_sub.get("status") == "expired"
                or existing_sub.get("original_transaction_id") != original_tx_id
            )
            activate_subscription(
                conn, user_id, product_id, original_tx_id, expires_at, environment,
            )
            if is_new_purchase:
                credits = settings.subscription_monthly_credits
                add_paid_credits(
                    conn, user_id, credits, product_id, original_tx_id, environment=environment,
                )
                # Record the subscription activation itself as a transaction.
                with conn.cursor() as cur:
                    cur.execute(
                        "INSERT INTO transactions (user_id, type, product_id, original_transaction_id, environment) "
                        "VALUES (%s, 'subscription', %s, %s, %s)",
                        (user_id, product_id, original_tx_id, environment),
                    )
                conn.commit()
                logger.info(
                    "Subscription activated + %d credits | user=%s environment=%s",
                    credits, user_id, environment,
                )
            else:
                logger.info(
                    "Subscription restored (no credits) | user=%s environment=%s",
                    user_id, environment,
                )
        return IAPVerifyResponse(
            success=True,
            subscriptionActivated=True,
            message="Subscription activated",
        )

    topup_map = settings.topup_product_map
    if product_id in topup_map:
        credits = topup_map[product_id]
        with connect(settings) as conn:
            add_paid_credits(
                conn, user_id, credits, product_id, original_tx_id, environment=environment,
            )
        logger.info(
            "Credits granted | user=%s product=%s credits=%d environment=%s",
            user_id, product_id, credits, environment,
        )
        return IAPVerifyResponse(
            success=True,
            creditsGranted=credits,
            message=f"{credits} credits granted",
        )

    raise HTTPException(status_code=400, detail=f"Unknown product ID: {product_id}")


# ---- Credit enforcement helpers (called from main.py) ----


def board_key_from_dict(board: dict) -> str:
    """Compute a stable key from board JSON, mirroring iOS `HistoryStore.key(for:)`."""
    moving = ",".join(str(p) for p in board.get("movingPositions", []))
    changed = board.get("changed") or {}
    return "|".join([
        board.get("method", ""),
        (board.get("castTime") or {}).get("gregorian", ""),
        (board.get("primary") or {}).get("name", ""),
        changed.get("name", ""),
        moving,
        board.get("question") or "",
    ])


def check_and_deduct_reading_credit(
    settings: Settings, user_id: uuid.UUID, board: dict
) -> str | None:
    """Ensure user has credits for a new reading. Returns error message or None.

    - All readings deduct 1 credit (free first, then paid).
    - Re-opening an existing reading (same board_key): no deduction.
    """
    _ensure_db(settings)
    board_key = board_key_from_dict(board)

    with connect(settings) as conn:
        # Check if reading already exists (re-open, no deduction).
        _, created = get_or_create_reading(conn, user_id, board_key)
        if not created:
            return None  # Already paid for this reading.

        # Deduct a credit.
        if not deduct_credit(conn, user_id, settings):
            return "Insufficient credits. Please subscribe or top up to request a reading."

    return None


def check_and_increment_question(
    settings: Settings, user_id: uuid.UUID, board: dict
) -> str | None:
    """Ensure user can ask a follow-up question. Returns error message or None.

    All users subject to max questions per reading limit.
    """
    _ensure_db(settings)
    board_key = board_key_from_dict(board)

    with connect(settings) as conn:
        # Ensure reading exists (should have been created by interpret).
        _, created = get_or_create_reading(conn, user_id, board_key)
        if created:
            # Reading wasn't created by interpret — deduct credit now.
            if not deduct_credit(conn, user_id, settings):
                return "Insufficient credits."

        if not increment_reading_questions(conn, user_id, board_key, settings):
            limit = settings.max_questions_per_reading
            return f"Question limit reached ({limit} per reading). Start a new reading to continue."

    return None
