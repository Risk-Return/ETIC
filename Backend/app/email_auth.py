"""邮箱验证码/密码登录：验证码生成/哈希、密码哈希 + 腾讯企业邮 SMTP 发信。

流程：
1. `POST /v1/auth/email/code`：生成 6 位数字验证码，HMAC 哈希后入库，SMTP 发送原文。
2. `POST /v1/auth/email/verify`：校验验证码 → 按邮箱创建/检索用户 → 签发会话 JWT。
3. `POST /v1/auth/email/password`：已设密码的用户可直接邮箱 + 密码登录（注册仍走验证码）。

无 SMTP 配置时自动 mock：验证码打日志、不真实发信，便于本地联调。
"""

from __future__ import annotations

import asyncio
import hashlib
import hmac
import logging
import re
import secrets
import smtplib
from email.header import Header
from email.mime.text import MIMEText
from email.utils import formataddr

from .config import Settings

logger = logging.getLogger("etic.email_auth")

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def is_valid_email(email: str) -> bool:
    return bool(_EMAIL_RE.match(email.strip()))


def generate_code() -> str:
    """6 位数字验证码（前导零保留）。"""
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_code(email: str, code: str, settings: Settings) -> str:
    """HMAC(jwt_secret, email + code)：库中不存验证码原文。"""
    message = f"{email.strip().lower()}:{code}".encode("utf-8")
    return hmac.new(
        settings.jwt_secret.encode("utf-8"), message, hashlib.sha256
    ).hexdigest()


# ---- Password hashing (PBKDF2-HMAC-SHA256, stdlib, no extra deps) ----

_PBKDF2_ITERATIONS = 600_000

PASSWORD_MIN_LENGTH = 8
PASSWORD_MAX_LENGTH = 128


def is_valid_password(password: str) -> bool:
    return PASSWORD_MIN_LENGTH <= len(password) <= PASSWORD_MAX_LENGTH


def hash_password(password: str) -> str:
    """随机盐 PBKDF2；格式 `pbkdf2_sha256$iterations$salt_hex$hash_hex`。"""
    salt = secrets.token_hex(16)
    dk = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), bytes.fromhex(salt), _PBKDF2_ITERATIONS
    )
    return f"pbkdf2_sha256${_PBKDF2_ITERATIONS}${salt}${dk.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        algo, iterations, salt, hex_hash = stored.split("$")
        if algo != "pbkdf2_sha256":
            return False
        dk = hashlib.pbkdf2_hmac(
            "sha256", password.encode("utf-8"), bytes.fromhex(salt), int(iterations)
        )
        return hmac.compare_digest(dk.hex(), hex_hash)
    except Exception:
        return False


def _build_message(to_email: str, code: str, settings: Settings) -> MIMEText:
    ttl = settings.email_code_ttl_minutes
    body = (
        f"您的 ETIC 登录验证码是：{code}\n"
        f"验证码 {ttl} 分钟内有效，请勿泄露给他人。\n\n"
        f"Your ETIC sign-in verification code is: {code}\n"
        f"It expires in {ttl} minutes. Do not share it with anyone.\n"
    )
    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = Header(f"ETIC 登录验证码 {code}", "utf-8")
    msg["From"] = formataddr((settings.smtp_from_name, settings.smtp_user))
    msg["To"] = to_email
    return msg


def _send_sync(to_email: str, code: str, settings: Settings) -> None:
    msg = _build_message(to_email, code, settings)
    with smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=15) as server:
        server.login(settings.smtp_user, settings.smtp_password)
        server.sendmail(settings.smtp_user, [to_email], msg.as_string())


async def send_verification_email(to_email: str, code: str, settings: Settings) -> None:
    """发送验证码邮件。mock 模式只打日志。发信失败抛异常由调用方处理。"""
    if settings.use_mock_smtp:
        logger.info("[MOCK SMTP] verification code for %s: %s", to_email, code)
        return
    await asyncio.to_thread(_send_sync, to_email, code, settings)
    logger.info("Verification code sent | to=%s", to_email)
