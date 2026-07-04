"""Auth module tests: JWT session token issuance/verification (no DB needed)."""

import time
import uuid

import jwt
import pytest

from app.auth import issue_session_jwt, verify_session_jwt
from app.config import Settings


def _test_settings() -> Settings:
    return Settings(
        mock_llm=True,
        jwt_secret="test-secret-key",
        jwt_expire_days=1,
    )


def test_issue_and_verify_session_jwt():
    settings = _test_settings()
    user_id = uuid.uuid4()
    token = issue_session_jwt(user_id, settings)
    assert isinstance(token, str)

    decoded_user_id = verify_session_jwt(token, settings)
    assert decoded_user_id == user_id


def test_verify_expired_jwt_fails():
    settings = _test_settings()
    user_id = uuid.uuid4()
    # Issue a token that's already expired.
    payload = {
        "sub": str(user_id),
        "iat": int(time.time()) - 7200,
        "exp": int(time.time()) - 3600,
    }
    expired_token = jwt.encode(payload, settings.jwt_secret, algorithm="HS256")
    with pytest.raises(Exception):
        verify_session_jwt(expired_token, settings)


def test_verify_invalid_signature_fails():
    settings = _test_settings()
    user_id = uuid.uuid4()
    token = issue_session_jwt(user_id, settings)
    with pytest.raises(Exception):
        verify_session_jwt(token, Settings(jwt_secret="wrong-secret"))


def test_verify_malformed_token_fails():
    settings = _test_settings()
    with pytest.raises(Exception):
        verify_session_jwt("not.a.jwt", settings)
