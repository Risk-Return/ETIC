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
