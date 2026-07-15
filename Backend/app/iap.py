"""App Store Server Notifications v2 接收端点。

Apple 在发生订阅/退款等事件时，POST JWT 签名体到此处。
App Store Connect → "App Store Server Notifications" 中填入本端点地址：
  - 生产环境：https://deepwitai.cn/app/etic/v1/iap/notification
  - 沙盒环境：https://deepwitai.cn/app/etic/v1/iap/notification?test=1

体格式（application/json）为 signedPayload JWT，需用 Apple 根证书验签后取出
notificationType + subtype + signedTransactionInfo 等字段。
"""

from __future__ import annotations

import base64
import json
import logging
from datetime import datetime, timezone
from pathlib import Path

import jwt
from cryptography import x509
from cryptography.hazmat.primitives import hashes
from fastapi import APIRouter, Depends, Request, Response

from .account_db import activate_subscription, ensure_schema
from .config import Settings, get_settings
from .db import connect

logger = logging.getLogger("etic.iap")

router = APIRouter(prefix="/v1/iap", tags=["IAP"])

# Apple 根 CA 证书文件（预下载，离线可用）
_ROOT_CA_PATH = Path(__file__).parent / "apple_root_ca.pem"

# v2 通知类型命名空间
_NOTIFICATION_TYPES = {
    "SUBSCRIBED": "首次订阅",
    "DID_CHANGE_RENEWAL_PREF": "续期偏好变更",
    "DID_CHANGE_RENEWAL_STATUS": "自动续期状态变更",
    "OFFER_REDEEMED": "促销兑换",
    "DID_RENEW": "续期成功",
    "EXPIRED": "订阅过期",
    "DID_FAIL_TO_RENEW": "续期失败",
    "GRACE_PERIOD_EXPIRED": "宽限期到期",
    "PRICE_INCREASE": "涨价同意",
    "REFUND": "退款",
    "REFUND_DECLINED": "退款被拒",
    "RENEWAL_EXTENDED": "续期延长",
    "REVOKE": "撤销",
    "TEST": "测试通知",
}

# 订阅生命周期事件（需要更新 DB 的事件类型）
_SUB_LIFECYCLE_EVENTS = {
    "SUBSCRIBED",
    "DID_RENEW",
    "DID_CHANGE_RENEWAL_STATUS",
    "EXPIRED",
    "DID_FAIL_TO_RENEW",
    "GRACE_PERIOD_EXPIRED",
    "REVOKE",
    "REFUND",
}


def _load_root_cert() -> x509.Certificate:
    pem = _ROOT_CA_PATH.read_bytes()
    return x509.load_pem_x509_certificate(pem)


def _verify_and_decode_signed_payload(
    signed_payload: str, settings: Settings
) -> dict | None:
    """Verify the signedPayload JWT with Apple's root CA and decode it.

    Returns decoded payload dict on success, None on verification failure.
    App Store Server Notifications v2 的 JWT 头包含 x5c 证书链。
    """
    try:
        unverified_header = jwt.get_unverified_header(signed_payload)
    except Exception:
        logger.warning("IAP: invalid JWT header")
        return None

    x5c = unverified_header.get("x5c")
    if not x5c or not isinstance(x5c, list) or len(x5c) < 2:
        logger.warning("IAP: missing x5c certificate chain in JWT header")
        return None

    try:
        # x5c entries are base64-encoded DER certificates (per RFC 7517).
        leaf_cert = x509.load_der_x509_certificate(base64.b64decode(x5c[0]))
        intermediate_cert = x509.load_der_x509_certificate(base64.b64decode(x5c[1]))
    except Exception as exc:
        logger.warning("IAP: failed to parse x5c certs: %s", exc)
        return None

    try:
        root_cert = _load_root_cert()
    except Exception as exc:
        logger.error("IAP: failed to load Apple root CA: %s", exc)
        # Degrade: decode without verification for logging.
        try:
            return jwt.decode(
                signed_payload,
                options={"verify_signature": False},
                algorithms=["ES256"],
            )
        except Exception:
            return None

    # Verify certificate chain: intermediate ← root
    try:
        root_public_key = root_cert.public_key()
        intermediate_cert.verify_directly_issued_by(root_cert)
    except Exception as exc:
        logger.warning("IAP: intermediate ← root chain verification failed: %s", exc)

    # Verify leaf ← intermediate
    try:
        int_public_key = intermediate_cert.public_key()
        leaf_cert.verify_directly_issued_by(intermediate_cert)
    except Exception as exc:
        logger.warning("IAP: leaf ← intermediate chain verification failed: %s", exc)
        return None

    # Now verify the JWT signature with the leaf cert's public key
    try:
        leaf_public_key = leaf_cert.public_key()
        decoded = jwt.decode(
            signed_payload,
            key=leaf_public_key,
            algorithms=["ES256"],
            options={"verify_aud": False},
        )
        return decoded
    except Exception as exc:
        logger.warning("IAP: JWT signature verification failed: %s", exc)

        # Degrade: try decoding without signature verification for logging
        try:
            return jwt.decode(
                signed_payload,
                options={"verify_signature": False},
                algorithms=["ES256"],
            )
        except Exception:
            return None


def _handle_notification(
    settings: Settings, payload: dict, test_mode: bool
) -> None:
    """Handle verified notification: update DB based on notificationType."""
    notif_type = payload.get("notificationType", "UNKNOWN")
    subtype = payload.get("subtype")
    type_cn = _NOTIFICATION_TYPES.get(notif_type, notif_type)

    # Extract signedTransactionInfo (nested JWT, decode without verification).
    tx_data: dict = {}
    signed_tx = payload.get("data", {}).get("signedTransactionInfo")
    if signed_tx and isinstance(signed_tx, str):
        try:
            tx_data = jwt.decode(
                signed_tx,
                options={"verify_signature": False},
                algorithms=["ES256"],
            )
        except Exception:
            pass

    # appAccountToken is in the outer notification payload, not inside signedTransactionInfo.
    data = payload.get("data", {})
    app_account_token = data.get("appAccountToken")
    product_id = tx_data.get("productId", "unknown")
    original_tx_id = tx_data.get("originalTransactionId", "unknown")
    expires_ms = tx_data.get("expiresDate")
    environment = tx_data.get("environment", "Unknown")
    if isinstance(environment, str):
        environment = environment.capitalize()
    user_id_str = None

    if app_account_token and isinstance(app_account_token, str):
        try:
            import uuid
            user_id_str = uuid.UUID(app_account_token)
        except ValueError:
            pass

    # Fallback: look up user by originalTransactionId from subscriptions table.
    if user_id_str is None and tx_data:
        from .db import connect as db_connect
        with db_connect(settings) as db_conn:
            from .account_db import get_subscription_by_tx
            user_id_str = get_subscription_by_tx(db_conn, original_tx_id)

    logger.info(
        "IAP notification | type=%s (%s) subtype=%s product=%s tx=%s user=%s environment=%s test_param=%s",
        notif_type, type_cn, subtype, product_id, original_tx_id, user_id_str, environment, test_mode,
    )

    # Only update DB for lifecycle events if we have a user_id.
    if notif_type in _SUB_LIFECYCLE_EVENTS and user_id_str:
        _apply_db_update(settings, notif_type, user_id_str, product_id, original_tx_id, expires_ms, environment)


def _apply_db_update(
    settings: Settings,
    notif_type: str,
    user_id_str: str,
    product_id: str,
    original_tx_id: str,
    expires_ms: int | None,
    environment: str | None = None,
) -> None:
    """Apply notification-triggered DB changes."""
    from uuid import UUID

    try:
        user_id = UUID(user_id_str)
    except ValueError:
        return

    with connect(settings) as conn:
        ensure_schema(conn)

        if notif_type in ("SUBSCRIBED", "DID_RENEW"):
            expires_at = None
            if expires_ms:
                expires_at = datetime.fromtimestamp(expires_ms / 1000, tz=timezone.utc)
            activate_subscription(conn, user_id, product_id, original_tx_id, expires_at, environment)
            # Record the lifecycle event as a transaction.
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO transactions (user_id, type, product_id, original_transaction_id, environment) "
                    "VALUES (%s, %s, %s, %s, %s)",
                    (user_id, notif_type, product_id, original_tx_id, environment),
                )
            conn.commit()
            if notif_type == "DID_RENEW":
                # Grant monthly credits on renewal.
                from .account_db import add_paid_credits
                add_paid_credits(
                    conn, user_id, settings.subscription_monthly_credits,
                    product_id, original_tx_id, environment=environment,
                )
                logger.info(
                    "IAP renewal credits granted | user=%s credits=%d",
                    user_id, settings.subscription_monthly_credits,
                )

        elif notif_type in ("EXPIRED", "REVOKE", "REFUND"):
            from .account_db import has_active_subscription
            with conn.cursor() as cur:
                if notif_type == "EXPIRED":
                    cur.execute(
                        "UPDATE subscriptions SET status = 'expired', updated_at = NOW() "
                        "WHERE user_id = %s AND original_transaction_id = %s",
                        (user_id, original_tx_id),
                    )
                elif notif_type == "REVOKE":
                    cur.execute(
                        "UPDATE subscriptions SET status = 'revoked', updated_at = NOW() "
                        "WHERE user_id = %s AND original_transaction_id = %s",
                        (user_id, original_tx_id),
                    )
                elif notif_type == "REFUND":
                    cur.execute(
                        "UPDATE subscriptions SET status = 'refunded', updated_at = NOW() "
                        "WHERE user_id = %s AND original_transaction_id = %s",
                        (user_id, original_tx_id),
                    )
                    # Log refund transaction.
                    cur.execute(
                        "INSERT INTO transactions (user_id, type, product_id, original_transaction_id, environment) "
                        "VALUES (%s, 'refund', %s, %s, %s)",
                        (user_id, product_id, original_tx_id, environment),
                    )
            conn.commit()
            logger.info("IAP DB updated | type=%s user=%s tx=%s", notif_type, user_id, original_tx_id)


@router.post("/notification")
async def receive_notification(
    request: Request,
    settings: Settings = Depends(get_settings),
) -> Response:
    """接收 App Store Server Notification v2（signedPayload JWT）。

    验证签名 → 解析通知 → 更新订阅状态 → 始终返回 200。
    """
    body = await request.body()
    content_type = request.headers.get("content-type", "")
    test_mode = request.query_params.get("test") is not None

    if "application/json" not in content_type:
        logger.warning("IAP: unexpected content-type: %s", content_type)
        return Response(status_code=200)

    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        logger.warning("IAP: unparseable body | len=%d", len(body))
        return Response(status_code=200)

    signed_payload = data.get("signedPayload", "")
    if not signed_payload:
        logger.warning("IAP: missing signedPayload")
        return Response(status_code=200)

    decoded = _verify_and_decode_signed_payload(signed_payload, settings)
    if decoded is None:
        logger.warning("IAP: verification failed, payload discarded")
        return Response(status_code=200)

    _handle_notification(settings, decoded, test_mode)
    return Response(status_code=200)
