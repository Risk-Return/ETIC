"""Account & billing tests: DB operations, API endpoints, credit enforcement.

Requires a Postgres database (same as RAG tests). Skips if DB is unavailable.
"""

import json
import uuid
from unittest.mock import AsyncMock, patch

import psycopg
import pytest
from asgi_lifespan import LifespanManager

from app.account import board_key_from_dict
from app.account_db import (
    add_paid_credits,
    activate_subscription,
    deduct_credit,
    ensure_schema,
    get_account_status,
    get_or_create_reading,
    get_or_create_user,
    has_active_subscription,
    increment_reading_questions,
)
from app.auth import issue_session_jwt
from app.config import Settings, get_settings
from app.db import connect
from app.main import app

import httpx

DEFAULT_DB_URL = "postgresql://etic:etic@localhost:5432/etic"

TEST_BOARD = {
    "method": "铜钱",
    "castTime": {"gregorian": "2024-01-15 14:30"},
    "primary": {"name": "山火贲"},
    "changed": {"name": "山雷颐"},
    "movingPositions": [3, 5],
    "question": "测试问题",
}


def _billing_settings() -> Settings:
    return Settings(
        mock_llm=True,
        billing_enabled=True,
        jwt_secret="test-secret",
        free_monthly_credits=3,
        max_questions_per_reading=3,
        database_url=DEFAULT_DB_URL,
    )


@pytest.fixture
def billing_settings(monkeypatch):
    """Force billing_enabled for interpret/chat tests."""
    get_settings.cache_clear()
    monkeypatch.setenv("ETIC_MOCK_LLM", "true")
    monkeypatch.setenv("ETIC_RAG_ENABLED", "false")
    monkeypatch.setenv("ETIC_BILLING_ENABLED", "true")
    monkeypatch.setenv("ETIC_JWT_SECRET", "test-secret")
    monkeypatch.setenv("ETIC_DATABASE_URL", DEFAULT_DB_URL)
    yield
    get_settings.cache_clear()


@pytest.fixture
def db_conn():
    """Provide a DB connection; skip if unavailable."""
    settings = _billing_settings()
    try:
        conn = psycopg.connect(settings.database_url)
        ensure_schema(conn)
        yield conn
        # Cleanup: only delete test-created users (ON DELETE CASCADE handles child tables).
        conn.execute(
            "DELETE FROM users WHERE apple_user_identifier LIKE 'apple-test-%' "
            "OR apple_user_identifier LIKE 'apple-api-test-%'"
        )
        conn.commit()
        conn.close()
    except psycopg.OperationalError as exc:
        pytest.skip(f"Postgres not available: {exc}")


# ---- DB operation tests ----


def test_get_or_create_user(db_conn):
    user_id, created = get_or_create_user(db_conn, "apple-test-sub-1", "test@test.com", "Test User")
    assert created
    assert isinstance(user_id, uuid.UUID)

    # Second call should return same user, not create.
    user_id2, created2 = get_or_create_user(db_conn, "apple-test-sub-1")
    assert not created2
    assert user_id2 == user_id


def test_credit_deduction_free_first(db_conn):
    settings = _billing_settings()
    user_id, _ = get_or_create_user(db_conn, "apple-test-sub-2")

    # Add free credits.
    with connect(settings) as conn:
        conn.execute(
            "UPDATE credit_balances SET free_credits = 3 WHERE user_id = %s",
            (user_id,),
        )
        conn.commit()

    # Deduct 1 — should come from free.
    assert deduct_credit(db_conn, user_id, settings)
    status = get_account_status(db_conn, user_id, settings)
    assert status["freeCredits"] == 2
    assert status["paidCredits"] == 0

    # Deduct remaining free.
    assert deduct_credit(db_conn, user_id, settings)
    assert deduct_credit(db_conn, user_id, settings)
    status = get_account_status(db_conn, user_id, settings)
    assert status["freeCredits"] == 0

    # No more free credits — should fail.
    assert not deduct_credit(db_conn, user_id, settings)


def test_credit_deduction_paid_after_free(db_conn):
    settings = _billing_settings()
    user_id, _ = get_or_create_user(db_conn, "apple-test-sub-3")

    with connect(settings) as conn:
        conn.execute(
            "UPDATE credit_balances SET free_credits = 1, paid_credits = 5 WHERE user_id = %s",
            (user_id,),
        )
        conn.commit()

    # First deduction from free.
    assert deduct_credit(db_conn, user_id, settings)
    status = get_account_status(db_conn, user_id, settings)
    assert status["freeCredits"] == 0
    assert status["paidCredits"] == 5

    # Second deduction from paid.
    assert deduct_credit(db_conn, user_id, settings)
    status = get_account_status(db_conn, user_id, settings)
    assert status["freeCredits"] == 0
    assert status["paidCredits"] == 4


def test_add_paid_credits(db_conn):
    settings = _billing_settings()
    user_id, _ = get_or_create_user(db_conn, "apple-test-sub-4")

    add_paid_credits(db_conn, user_id, 10, "ai.etic.app.credits.10", "tx-123")
    status = get_account_status(db_conn, user_id, settings)
    assert status["paidCredits"] == 10


def test_activate_subscription(db_conn):
    settings = _billing_settings()
    user_id, _ = get_or_create_user(db_conn, "apple-test-sub-5")

    activate_subscription(db_conn, user_id, "ai.etic.app.subscription.monthly", "tx-456")
    assert has_active_subscription(db_conn, user_id)

    status = get_account_status(db_conn, user_id, settings)
    assert status["subscription"] is not None
    assert status["subscription"]["status"] == "active"


def test_reading_question_limit(db_conn):
    settings = _billing_settings()
    user_id, _ = get_or_create_user(db_conn, "apple-test-sub-6")
    board_key = "test-board-key-1"

    _, created = get_or_create_reading(db_conn, user_id, board_key)
    assert created

    # Ask 3 questions.
    for i in range(3):
        assert increment_reading_questions(db_conn, user_id, board_key, settings)

    # 4th should fail.
    assert not increment_reading_questions(db_conn, user_id, board_key, settings)


def test_reading_reopen_no_new_record(db_conn):
    settings = _billing_settings()
    user_id, _ = get_or_create_user(db_conn, "apple-test-sub-7")
    board_key = "test-board-key-2"

    _, created1 = get_or_create_reading(db_conn, user_id, board_key)
    assert created1

    _, created2 = get_or_create_reading(db_conn, user_id, board_key)
    assert not created2


def test_board_key_from_dict():
    key = board_key_from_dict(TEST_BOARD)
    assert "铜钱" in key
    assert "山火贲" in key
    assert "3,5" in key


# ---- API endpoint tests (with mocked Apple Sign In) ----


@pytest.fixture
async def billing_client(billing_settings):
    async with LifespanManager(app):
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as c:
            yield c


def _make_apple_identity_token_mock(sub: str = "apple-api-test-sub") -> str:
    """Create a mock Apple identity token (for patching)."""
    import jwt as pyjwt

    payload = {
        "iss": "https://appleid.apple.com",
        "aud": "ai.etic.app",
        "sub": sub,
        "exp": int(time.time()) + 3600,
        "iat": int(time.time()),
    }
    return pyjwt.encode(payload, "fake-key", algorithm="HS256")


import time


@pytest.mark.asyncio
async def test_apple_sign_in_endpoint(billing_client, db_conn):
    """Test POST /v1/auth/apple with mocked Apple verification."""
    mock_claims = {
        "iss": "https://appleid.apple.com",
        "aud": "ai.etic.app",
        "sub": "apple-api-test-sub-signin",
        "email": "test@example.com",
    }

    with patch("app.account.verify_apple_identity_token", new_callable=AsyncMock) as mock_verify:
        mock_verify.return_value = mock_claims
        resp = await billing_client.post("/v1/auth/apple", json={
            "identityToken": "fake-token",
            "email": "test@example.com",
            "fullName": "Test User",
        })

    assert resp.status_code == 200
    body = resp.json()
    assert "sessionToken" in body
    assert "account" in body
    assert body["account"]["userId"]
    assert body["account"]["freeMonthlyCredits"] == 3
    assert body["account"]["maxQuestionsPerReading"] == 3


@pytest.mark.asyncio
async def test_account_me_endpoint(billing_client, db_conn):
    """Test GET /v1/account/me with a valid session token."""
    settings = _billing_settings()
    user_id, _ = get_or_create_user(db_conn, "apple-api-test-me", "me@test.com")
    token = issue_session_jwt(user_id, settings)

    resp = await billing_client.get("/v1/account/me", headers={
        "Authorization": f"Bearer {token}",
    })
    assert resp.status_code == 200
    body = resp.json()
    assert body["userId"] == str(user_id)


@pytest.mark.asyncio
async def test_account_me_requires_auth(billing_client):
    """Test GET /v1/account/me without token returns 401."""
    resp = await billing_client.get("/v1/account/me")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_interpret_requires_auth_when_billing(billing_client, billing_settings):
    """Test POST /v1/interpret returns 401 when billing is on and no token."""
    resp = await billing_client.post("/v1/interpret", json={"board": TEST_BOARD})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_interpret_deducts_credit(billing_client, db_conn):
    """Test POST /v1/interpret deducts a credit when billing is on."""
    settings = _billing_settings()
    user_id, _ = get_or_create_user(db_conn, "apple-api-test-credit")
    token = issue_session_jwt(user_id, settings)

    # Give user 3 free credits.
    with connect(settings) as conn:
        conn.execute(
            "UPDATE credit_balances SET free_credits = 3 WHERE user_id = %s",
            (user_id,),
        )
        conn.commit()

    resp = await billing_client.post("/v1/interpret", json={"board": TEST_BOARD}, headers={
        "Authorization": f"Bearer {token}",
    })
    assert resp.status_code == 200

    # Verify credit was deducted.
    with connect(settings) as conn:
        status = get_account_status(conn, user_id, settings)
    assert status["freeCredits"] == 2


@pytest.mark.asyncio
async def test_interpret_no_credits_returns_402(billing_client, db_conn):
    """Test POST /v1/interpret returns 402 when user has no credits."""
    settings = _billing_settings()
    user_id, _ = get_or_create_user(db_conn, "apple-api-test-nocredit")
    token = issue_session_jwt(user_id, settings)

    # User has 0 credits.
    resp = await billing_client.post("/v1/interpret", json={"board": TEST_BOARD}, headers={
        "Authorization": f"Bearer {token}",
    })
    assert resp.status_code == 402


@pytest.mark.asyncio
async def test_chat_question_limit(billing_client, db_conn):
    """Test POST /v1/chat enforces 3-question limit."""
    settings = _billing_settings()
    user_id, _ = get_or_create_user(db_conn, "apple-api-test-chatlimit")

    # Give credits and create reading.
    with connect(settings) as conn:
        conn.execute(
            "UPDATE credit_balances SET free_credits = 5 WHERE user_id = %s",
            (user_id,),
        )
        conn.commit()

    token = issue_session_jwt(user_id, settings)

    # First, call interpret to create the reading.
    resp = await billing_client.post("/v1/interpret", json={"board": TEST_BOARD}, headers={
        "Authorization": f"Bearer {token}",
    })
    assert resp.status_code == 200

    # Ask 3 follow-up questions.
    for i in range(3):
        resp = await billing_client.post("/v1/chat", json={
            "board": TEST_BOARD,
            "messages": [{"role": "user", "content": f"Question {i+1}"}],
        }, headers={
            "Authorization": f"Bearer {token}",
        })
        assert resp.status_code == 200

    # 4th question should return 429.
    resp = await billing_client.post("/v1/chat", json={
        "board": TEST_BOARD,
        "messages": [{"role": "user", "content": "Question 4"}],
    }, headers={
        "Authorization": f"Bearer {token}",
    })
    assert resp.status_code == 429


@pytest.mark.asyncio
async def test_interpret_reopen_no_double_charge(billing_client, db_conn):
    """Test re-opening same reading doesn't deduct credit again."""
    settings = _billing_settings()
    user_id, _ = get_or_create_user(db_conn, "apple-api-test-reopen")

    with connect(settings) as conn:
        conn.execute(
            "UPDATE credit_balances SET free_credits = 3 WHERE user_id = %s",
            (user_id,),
        )
        conn.commit()

    token = issue_session_jwt(user_id, settings)

    # First interpret — deducts 1 credit.
    resp = await billing_client.post("/v1/interpret", json={"board": TEST_BOARD}, headers={
        "Authorization": f"Bearer {token}",
    })
    assert resp.status_code == 200

    # Second interpret with same board — should NOT deduct.
    resp = await billing_client.post("/v1/interpret", json={"board": TEST_BOARD}, headers={
        "Authorization": f"Bearer {token}",
    })
    assert resp.status_code == 200

    with connect(settings) as conn:
        status = get_account_status(conn, user_id, settings)
    assert status["freeCredits"] == 2  # Only deducted once.


@pytest.mark.asyncio
async def test_subscriber_credit_deduction(billing_client, db_conn):
    """Test subscribers also get credits deducted (credit-based, not unlimited)."""
    settings = _billing_settings()
    user_id, _ = get_or_create_user(db_conn, "apple-api-test-subscriber",
                                     free_credits=settings.free_monthly_credits)

    activate_subscription(db_conn, user_id, "ai.etic.app.subscription.monthly", "tx-sub")
    # Simulate the credits granted on subscription purchase.
    add_paid_credits(db_conn, user_id, settings.subscription_monthly_credits,
                     "ai.etic.app.subscription.monthly", "tx-sub", environment="Sandbox")
    token = issue_session_jwt(user_id, settings)

    # Verify initial credit state: free credits + subscription credits.
    with connect(settings) as conn:
        status = get_account_status(conn, user_id, settings)
    assert status["freeCredits"] == settings.free_monthly_credits
    assert status["paidCredits"] == settings.subscription_monthly_credits

    resp = await billing_client.post("/v1/interpret", json={"board": TEST_BOARD}, headers={
        "Authorization": f"Bearer {token}",
    })
    assert resp.status_code == 200

    # Subscriber should have 1 free credit deducted (free first).
    with connect(settings) as conn:
        status = get_account_status(conn, user_id, settings)
    assert status["freeCredits"] == settings.free_monthly_credits - 1
