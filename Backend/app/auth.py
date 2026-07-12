"""Apple Sign In 验签 + 会话 JWT 签发/校验 + client_secret 生成。

流程：
1. iOS 端 Sign in with Apple 获取 `identityToken`（Apple 签名的 JWT）。
2. iOS 将 identityToken 发给 `POST /v1/auth/apple`。
3. 后端用 Apple 公钥验签，取出 `sub`（Apple 稳定用户标识）。
4. 后端创建/检索用户，签发会话 JWT（HS256）返回给客户端。
5. 客户端后续请求携带 `Authorization: Bearer <session_jwt>`。

client_secret 用于服务端调用 Apple API（如验证 authorization_code、刷新 token）。
"""

from __future__ import annotations

import logging
import time
import uuid
from pathlib import Path
from typing import Optional

import httpx
import jwt
from fastapi import Depends, HTTPException, Request

from .config import Settings, get_settings
from .db import connect

logger = logging.getLogger("etic.auth")

APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"

# Cache Apple public keys (fetched on first use, refreshed on key rotation).
_apple_jwks: dict | None = None
_apple_jwks_fetched_at: float = 0


def _load_private_key(path: str) -> str:
    raw = (Path(path).read_text(encoding="ascii")).strip()
    if not raw.startswith("-----BEGIN"):
        # Prepend header if the key was stored as raw base64.
        raw = "-----BEGIN PRIVATE KEY-----\n" + raw + "\n-----END PRIVATE KEY-----"
    return raw


def generate_client_secret(settings: Settings) -> str:
    """Generate a client_secret JWT for server-to-server Apple API calls.

    Uses the Sign in with Apple private key (ES256).
    Returns a JWT valid for up to 6 months (Apple max).
    """
    if not settings.apple_team_id:
        raise ValueError("apple_team_id is required for client_secret generation")

    private_key = _load_private_key(settings.apple_siwa_key_path)
    now = int(time.time())
    payload = {
        "iss": settings.apple_team_id,
        "iat": now,
        "exp": now + 180 * 86400,  # 6 months
        "aud": APPLE_ISSUER,
        "sub": settings.apple_bundle_id,
    }
    headers = {
        "kid": settings.apple_siwa_key_id,
        "alg": "ES256",
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers=headers)

# Cache Apple public keys (fetched on first use, refreshed on key rotation).
_apple_jwks: dict | None = None
_apple_jwks_fetched_at: float = 0


async def _fetch_apple_jwks() -> dict:
    global _apple_jwks, _apple_jwks_fetched_at
    # Cache for 1 hour; Apple rotates keys infrequently.
    if _apple_jwks and time.time() - _apple_jwks_fetched_at < 3600:
        return _apple_jwks
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(APPLE_KEYS_URL)
        resp.raise_for_status()
        _apple_jwks = resp.json()
        _apple_jwks_fetched_at = time.time()
    return _apple_jwks


async def verify_apple_identity_token(
    identity_token: str, settings: Settings
) -> dict:
    """Verify Apple identity token JWT and return decoded claims.

    Raises ValueError on verification failure.
    """
    jwks = await _fetch_apple_jwks()
    unverified_header = jwt.get_unverified_header(identity_token)
    kid = unverified_header.get("kid")
    if not kid:
        raise ValueError("Apple identity token missing kid header")

    # Find matching key.
    key = None
    for k in jwks.get("keys", []):
        if k.get("kid") == kid:
            key = k
            break
    if key is None:
        # Force refresh and retry once.
        global _apple_jwks, _apple_jwks_fetched_at
        _apple_jwks = None
        jwks = await _fetch_apple_jwks()
        for k in jwks.get("keys", []):
            if k.get("kid") == kid:
                key = k
                break
    if key is None:
        raise ValueError("Apple identity token signed with unknown key")

    public_key = jwt.algorithms.RSAAlgorithm.from_jwk(key)
    decoded = jwt.decode(
        identity_token,
        key=public_key,
        algorithms=["RS256"],
        audience=settings.apple_bundle_id,
        issuer=APPLE_ISSUER,
    )
    return decoded


def issue_session_jwt(user_id: uuid.UUID, settings: Settings) -> str:
    """Issue a session JWT for the given user."""
    now = int(time.time())
    payload = {
        "sub": str(user_id),
        "iat": now,
        "exp": now + settings.jwt_expire_days * 86400,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def verify_session_jwt(token: str, settings: Settings) -> uuid.UUID:
    """Verify a session JWT and return the user_id. Raises ValueError on failure."""
    payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    sub = payload.get("sub")
    if not sub:
        raise ValueError("Session token missing sub claim")
    return uuid.UUID(sub)


async def get_current_user_id(
    request: Request,
    settings: Settings = Depends(get_settings),
) -> Optional[uuid.UUID]:
    """FastAPI dependency: extract user_id from Authorization header.

    Returns None if no token is present (for optional auth).
    Raises HTTPException 401 if token is invalid.
    """
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None
    token = auth_header[7:]
    try:
        user_id = verify_session_jwt(token, settings)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired session token")

    # 会话 JWT 有效，但对应用户可能已被删除（如库重置）。此时视为无效鉴权，
    # 返回 401 让客户端重新登录，避免后续 FK 约束导致 500。
    from . import account_db

    with connect(settings) as conn:
        if account_db.get_user_by_id(conn, user_id) is None:
            raise HTTPException(status_code=401, detail="Session user no longer exists")
    return user_id


async def require_user_id(
    user_id: Optional[uuid.UUID] = Depends(get_current_user_id),
) -> uuid.UUID:
    """FastAPI dependency: require a valid session token."""
    if user_id is None:
        raise HTTPException(status_code=401, detail="Authentication required")
    return user_id


def get_or_create_user_from_apple(
    settings: Settings,
    apple_sub: str,
    email: Optional[str] = None,
    name: Optional[str] = None,
) -> tuple[uuid.UUID, bool]:
    """Create or retrieve user by Apple sub. Returns (user_id, created)."""
    with connect(settings) as conn:
        from . import account_db
        account_db.ensure_schema(conn)
        return account_db.get_or_create_user(
            conn, apple_sub, email, name, settings.free_monthly_credits
        )
