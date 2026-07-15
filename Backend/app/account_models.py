"""账号 & 计费请求/响应模型。"""

from typing import Optional

from pydantic import BaseModel


class AppleAuthRequest(BaseModel):
    """iOS Sign in with Apple 后提交的 identity token。"""

    identityToken: str
    # 首次授权时 Apple 会返回 email / fullName，后续授权不返回。
    email: Optional[str] = None
    fullName: Optional[str] = None


class EmailCodeRequest(BaseModel):
    """请求发送邮箱验证码。"""

    email: str


class EmailCodeResponse(BaseModel):
    """验证码发送结果 + 重发冷却秒数。"""

    success: bool
    cooldownSeconds: int
    message: str = ""


class EmailVerifyRequest(BaseModel):
    """提交邮箱 + 验证码换取会话令牌。"""

    email: str
    code: str


class AccountStatus(BaseModel):
    """账号状态：额度、订阅、限额。"""

    userId: str
    freeCredits: int
    paidCredits: int
    totalCredits: int
    freeMonthlyCredits: int
    maxQuestionsPerReading: int
    subscription: Optional[dict] = None


class AuthResponse(BaseModel):
    """登录成功后返回的会话令牌 + 账号状态（Apple / 邮箱验证码通用）。"""

    sessionToken: str
    account: AccountStatus


class IAPVerifyRequest(BaseModel):
    """StoreKit 2 购买后提交交易 JWS 供后端记录。"""

    jwsRepresentation: str
    productId: str
    originalTransactionId: Optional[str] = None


class IAPVerifyResponse(BaseModel):
    """IAP 验证结果。"""

    success: bool
    creditsGranted: int = 0
    subscriptionActivated: bool = False
    message: str = ""
