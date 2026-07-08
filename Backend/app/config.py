from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """后端配置，全部经环境变量注入（key 不入库、不下发客户端）。"""

    model_config = SettingsConfigDict(env_prefix="ETIC_", env_file=".env", extra="ignore")

    # LLM provider（OpenAI 兼容协议：DeepSeek / 通义 / OpenAI 等均可）。
    llm_base_url: str = "https://api.deepseek.com/v1"
    llm_model: str = "deepseek-chat"
    llm_api_key: str = ""
    llm_temperature: float = 0.7
    llm_timeout_seconds: float = 60.0

    # 无 key（或显式开启）时返回桩文本，便于本地联调与测试。
    mock_llm: bool = False

    # 多轮对话最多携带的历史消息条数（不含 system / 盘面）。
    max_history_messages: int = 20

    # ---- 内容安全审核（M6）----
    # 开启后，起卦问题 / 追问文本先过确定性审核：高危类直接拒绝（不调 LLM），
    # 敏感类放行但向提示词注入更强的去绝对化 / 免责约束。关闭时兼容旧流程。
    moderation_enabled: bool = True

    # ---- RAG（卦爻辞检索 grounding，M5）----
    # 开启后，解读前会按本卦/变卦/动爻检索周易经文拼入 Prompt。需先灌库。
    rag_enabled: bool = False
    database_url: str = "postgresql://etic:etic@localhost:5432/etic"

    # embeddings（OpenAI 兼容 /embeddings；为空则回退到 llm_* 的 key/base_url）。
    embed_base_url: str = ""
    embed_model: str = "text-embedding-3-small"
    embed_api_key: str = ""
    # 维度：mock 与真实 provider 须一致；切换 provider 后需重新灌库。
    embed_dim: int = 256

    # 检索：向量召回条数 + 是否附带彖辞。
    rag_top_k: int = 4
    rag_include_tuan: bool = False

    # ---- 账号 & 计费（M6）----
    # Apple Sign In 验签：identity token 的 audience 为 bundle ID。
    apple_bundle_id: str = "ai.etic.app"
    # 后端签发会话 JWT 的密钥（随机长字符串，切勿泄露）。
    jwt_secret: str = "change-me-in-production"
    # 会话 JWT 有效期（天）。
    jwt_expire_days: int = 30
    # 每月免费解读次数。
    free_monthly_credits: int = 3
    # 每次解读最多追问次数。
    max_questions_per_reading: int = 3
    # 计费系统是否启用（关闭时 interpret/chat 不鉴权、不扣费，兼容旧流程）。
    billing_enabled: bool = False
    # 开发模式：启用测试登录端点（POST /v1/auth/test），跳过 Apple 验签。
    dev_mode: bool = False

    # StoreKit 商品 ID（需与 App Store Connect 中配置一致）。
    subscription_product_id: str = "ai.etic.app.subscription.monthly"
    # 充值商品 ID → 额度数映射，格式 "product_id:credits,..."
    topup_products: str = (
        "ai.etic.app.credits.5:5,"
        "ai.etic.app.credits.10:10,"
        "ai.etic.app.credits.25:25"
    )

    # ---- Apple 密钥（Sign in with Apple / App Store Server Notifications）----
    # Apple Developer Team ID（Membership → 右上角可查）。
    apple_team_id: str = ""
    # Sign in with Apple 私钥（用于生成 client_secret 调用 Apple 服务端 API）。
    apple_siwa_key_id: str = "L42755A2C3"
    apple_siwa_key_path: str = "keys/logo-in/AuthKey_L42755A2C3.p8"
    # App Store Server Notifications 验签密钥（验证 Apple 签名）。
    apple_notification_prod_key_path: str = "keys/notification/production/AuthKey_KRAL2SFAXJ.p8"
    apple_notification_sandbox_key_path: str = "keys/notification/sandbox/AuthKey_SQKM8TVF57.p8"

    @property
    def topup_product_map(self) -> dict[str, int]:
        result: dict[str, int] = {}
        for pair in self.topup_products.split(","):
            pair = pair.strip()
            if ":" not in pair:
                continue
            pid, credits = pair.rsplit(":", 1)
            result[pid.strip()] = int(credits)
        return result

    @property
    def use_mock(self) -> bool:
        return self.mock_llm or not self.llm_api_key

    @property
    def effective_embed_base_url(self) -> str:
        return self.embed_base_url or self.llm_base_url

    @property
    def effective_embed_api_key(self) -> str:
        return self.embed_api_key or self.llm_api_key

    @property
    def use_mock_embeddings(self) -> bool:
        return self.mock_llm or not self.effective_embed_api_key


@lru_cache
def get_settings() -> Settings:
    return Settings()
