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

    @property
    def use_mock(self) -> bool:
        return self.mock_llm or not self.llm_api_key


@lru_cache
def get_settings() -> Settings:
    return Settings()
