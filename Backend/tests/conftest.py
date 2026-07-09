import json
import os
from pathlib import Path

import pytest

from app.config import Settings

FIXTURES = Path(__file__).parent / "fixtures"

DEFAULT_DB_URL = "postgresql://etic:etic@localhost:5432/etic"


@pytest.fixture
def board_json() -> dict:
    return json.loads((FIXTURES / "board.json").read_text(encoding="utf-8"))


@pytest.fixture
def board_meihua_json() -> dict:
    """梅花起卦盘面（schema 1.1.0，含 meihua 体用视图），由引擎真实排盘生成。"""
    return json.loads((FIXTURES / "board_meihua.json").read_text(encoding="utf-8"))


@pytest.fixture(scope="session")
def rag_settings() -> Settings:
    return Settings(
        mock_llm=True,
        rag_enabled=True,
        embed_dim=256,
        database_url=os.environ.get("ETIC_DATABASE_URL", DEFAULT_DB_URL),
    )


@pytest.fixture(scope="session")
def rag_db(rag_settings):
    """灌好周易语料的 pgvector 库；DB 不可用时跳过相关测试。"""

    import psycopg

    from app.rag import store
    from app.rag.corpus import build_documents
    from app.rag.embeddings import _mock_embed_one

    try:
        with store.connect(rag_settings) as conn:
            docs = build_documents(include_tuan=False)
            vectors = [
                _mock_embed_one(d.content, rag_settings.embed_dim) for d in docs
            ]
            store.ensure_schema(conn, rag_settings.embed_dim)
            store.ingest(conn, docs, vectors)
    except psycopg.OperationalError as exc:  # 无可用 DB
        pytest.skip(f"pgvector 数据库不可用，跳过 RAG 集成测试：{exc}")
    return rag_settings
