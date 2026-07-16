"""邮箱密码登录测试：密码哈希、设置密码、密码登录端点。

DB/API 测试需要 Postgres，不可用时跳过。
"""

import time

import httpx
import psycopg
import pytest
from asgi_lifespan import LifespanManager

from app.account_db import (
    ensure_schema,
    get_or_create_user_by_email,
    get_user_auth_by_email,
    set_password_hash,
)
from app.auth import issue_session_jwt
from app.config import Settings, get_settings
from app.email_auth import hash_password, is_valid_password, verify_password
from app.main import app

DEFAULT_DB_URL = "postgresql://etic:etic@localhost:5432/etic"


def _settings() -> Settings:
    return Settings(
        mock_llm=True,
        billing_enabled=True,
        jwt_secret="test-secret",
        free_monthly_credits=3,
        database_url=DEFAULT_DB_URL,
    )


@pytest.fixture
def db_conn():
    settings = _settings()
    try:
        conn = psycopg.connect(settings.database_url)
        ensure_schema(conn)
        yield conn
        conn.execute("DELETE FROM users WHERE email LIKE 'pwdtest-%'")
        conn.commit()
        conn.close()
    except psycopg.OperationalError as exc:
        pytest.skip(f"Postgres not available: {exc}")


@pytest.fixture
def pwd_settings(monkeypatch):
    get_settings.cache_clear()
    monkeypatch.setenv("ETIC_MOCK_LLM", "true")
    monkeypatch.setenv("ETIC_RAG_ENABLED", "false")
    monkeypatch.setenv("ETIC_BILLING_ENABLED", "true")
    monkeypatch.setenv("ETIC_JWT_SECRET", "test-secret")
    monkeypatch.setenv("ETIC_DATABASE_URL", DEFAULT_DB_URL)
    yield
    get_settings.cache_clear()


@pytest.fixture
async def client(pwd_settings):
    async with LifespanManager(app):
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as c:
            yield c


# ---- Unit tests (no DB) ----


def test_is_valid_password():
    assert is_valid_password("12345678")
    assert is_valid_password("a" * 128)
    assert not is_valid_password("1234567")
    assert not is_valid_password("a" * 129)
    assert not is_valid_password("")


def test_password_hash_roundtrip():
    stored = hash_password("s3cret-Passw0rd")
    assert stored.startswith("pbkdf2_sha256$")
    assert verify_password("s3cret-Passw0rd", stored)
    assert not verify_password("wrong-password", stored)


def test_password_hash_salted():
    assert hash_password("same-password") != hash_password("same-password")


def test_verify_password_malformed_stored():
    assert not verify_password("whatever", "")
    assert not verify_password("whatever", "not-a-hash")
    assert not verify_password("whatever", "md5$1$aa$bb")


# ---- DB operation tests ----


def test_set_and_get_password_hash(db_conn):
    email = "pwdtest-1@example.com"
    user_id, _ = get_or_create_user_by_email(db_conn, email, free_credits=3)

    user = get_user_auth_by_email(db_conn, email)
    assert user["id"] == user_id
    assert user["password_hash"] is None

    set_password_hash(db_conn, user_id, hash_password("password123"))
    user = get_user_auth_by_email(db_conn, "Pwdtest-1@Example.COM")
    assert user["id"] == user_id
    assert verify_password("password123", user["password_hash"])


# ---- API endpoint tests ----


@pytest.mark.asyncio
async def test_set_password_and_login_flow(client, db_conn):
    settings = _settings()
    email = f"pwdtest-flow-{int(time.time())}@example.com"
    user_id, _ = get_or_create_user_by_email(db_conn, email, free_credits=3)
    token = issue_session_jwt(user_id, settings)

    # hasPassword false before setting.
    resp = await client.get(
        "/v1/account/me", headers={"Authorization": f"Bearer {token}"}
    )
    assert resp.status_code == 200
    assert resp.json()["hasPassword"] is False

    # Set password (session-authenticated).
    resp = await client.post(
        "/v1/account/password",
        json={"newPassword": "password123"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["success"]

    # Password login succeeds.
    resp = await client.post(
        "/v1/auth/email/password",
        json={"email": email.upper(), "password": "password123"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["account"]["userId"] == str(user_id)
    assert body["account"]["hasPassword"] is True
    assert "sessionToken" in body

    # Change password; old one stops working.
    resp = await client.post(
        "/v1/account/password",
        json={"newPassword": "new-password-456"},
        headers={"Authorization": f"Bearer {body['sessionToken']}"},
    )
    assert resp.status_code == 200
    resp = await client.post(
        "/v1/auth/email/password",
        json={"email": email, "password": "password123"},
    )
    assert resp.status_code == 401
    resp = await client.post(
        "/v1/auth/email/password",
        json={"email": email, "password": "new-password-456"},
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_password_login_wrong_password(client, db_conn):
    email = f"pwdtest-wrong-{int(time.time())}@example.com"
    user_id, _ = get_or_create_user_by_email(db_conn, email)
    set_password_hash(db_conn, user_id, hash_password("correct-password"))

    resp = await client.post(
        "/v1/auth/email/password",
        json={"email": email, "password": "wrong-password"},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_password_login_no_password_set(client, db_conn):
    email = f"pwdtest-nopwd-{int(time.time())}@example.com"
    get_or_create_user_by_email(db_conn, email)

    resp = await client.post(
        "/v1/auth/email/password",
        json={"email": email, "password": "any-password"},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_password_login_unknown_email(client, db_conn):
    resp = await client.post(
        "/v1/auth/email/password",
        json={"email": "pwdtest-nobody@example.com", "password": "any-password"},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_set_password_too_short(client, db_conn):
    settings = _settings()
    email = f"pwdtest-short-{int(time.time())}@example.com"
    user_id, _ = get_or_create_user_by_email(db_conn, email)
    token = issue_session_jwt(user_id, settings)

    resp = await client.post(
        "/v1/account/password",
        json={"newPassword": "short"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_set_password_requires_auth(client):
    resp = await client.post(
        "/v1/account/password", json={"newPassword": "password123"}
    )
    assert resp.status_code == 401
