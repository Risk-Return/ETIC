"""账号 & 计费路由：Apple Sign In、账号状态、IAP 验证。

所有端点前缀 `/v1`，与解读端点同级。
"""

from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timedelta, timezone

import jwt as pyjwt
from fastapi import APIRouter, Depends, HTTPException

from .account_db import (
    activate_subscription,
    add_paid_credits,
    deduct_credit,
    ensure_schema,
    get_account_status,
    get_or_create_reading,
    get_or_create_user,
    has_active_subscription,
    increment_reading_questions,
)
from .account_models import (
    AccountStatus,
    AppleAuthRequest,
    AuthResponse,
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
        # Some StoreKit JWS tokens are nested (signedTransactionInfo).
        # Fall back to trusting the client-provided productId.
        unverified = {}

    product_id = req.productId
    original_tx_id = req.originalTransactionId or str(
        unverified.get("originalTransactionId", "")
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
            activate_subscription(
                conn, user_id, product_id, original_tx_id, expires_at
            )
        logger.info("Subscription activated | user=%s product=%s", user_id, product_id)
        return IAPVerifyResponse(
            success=True,
            subscriptionActivated=True,
            message="Subscription activated",
        )

    topup_map = settings.topup_product_map
    if product_id in topup_map:
        credits = topup_map[product_id]
        with connect(settings) as conn:
            add_paid_credits(conn, user_id, credits, product_id, original_tx_id)
        logger.info("Credits granted | user=%s product=%s credits=%d", user_id, product_id, credits)
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

    - Subscribers: unlimited, no deduction.
    - Free/Paid credits: deduct 1 (free first).
    - Re-opening an existing reading (same board_key): no deduction.
    """
    _ensure_db(settings)
    board_key = board_key_from_dict(board)

    with connect(settings) as conn:
        # Check if reading already exists (re-open, no deduction).
        _, created = get_or_create_reading(conn, user_id, board_key)
        if not created:
            return None  # Already paid for this reading.

        # New reading — check subscription first.
        if has_active_subscription(conn, user_id):
            return None  # Subscribers read for free.

        # Deduct a credit.
        if not deduct_credit(conn, user_id, settings):
            return "Insufficient credits. Please subscribe or top up to request a reading."

    return None


def check_and_increment_question(
    settings: Settings, user_id: uuid.UUID, board: dict
) -> str | None:
    """Ensure user can ask a follow-up question. Returns error message or None.

    - Subscribers: still subject to max questions per reading.
    - Non-subscribers: same limit.
    """
    _ensure_db(settings)
    board_key = board_key_from_dict(board)

    with connect(settings) as conn:
        # Ensure reading exists (should have been created by interpret).
        _, created = get_or_create_reading(conn, user_id, board_key)
        if created:
            # Reading wasn't created by interpret — deduct credit now.
            if not has_active_subscription(conn, user_id):
                if not deduct_credit(conn, user_id, settings):
                    return "Insufficient credits."

        if not increment_reading_questions(conn, user_id, board_key, settings):
            limit = settings.max_questions_per_reading
            return f"Question limit reached ({limit} per reading). Start a new reading to continue."

    return None
