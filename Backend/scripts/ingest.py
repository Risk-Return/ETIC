"""把周易经文语料灌入 pgvector 向量库。

用法（先起好 Postgres+pgvector，见 docker-compose.yml）：
    python scripts/ingest.py
读取 `app/rag/data/zhouyi.json` → 展开为 卦辞/爻辞(/彖辞) 文档 → 向量化 → 写入库。
无 embeddings key 时用确定性 mock 向量（可离线灌库与联调）。
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import get_settings  # noqa: E402
from app.rag import store  # noqa: E402
from app.rag.corpus import build_documents  # noqa: E402
from app.rag.embeddings import embed_texts  # noqa: E402


async def main() -> None:
    settings = get_settings()
    docs = build_documents(include_tuan=settings.rag_include_tuan)
    print(f"语料：{len(docs)} 条文档（卦辞/爻辞{'/彖辞' if settings.rag_include_tuan else ''}）")
    print(
        "embeddings："
        + ("mock（确定性本地向量）" if settings.use_mock_embeddings else settings.embed_model)
        + f"，维度 {settings.embed_dim}"
    )

    vectors = await embed_texts(settings, [d.content for d in docs])
    assert len(vectors) == len(docs)
    if vectors and len(vectors[0]) != settings.embed_dim:
        raise SystemExit(
            f"向量维度 {len(vectors[0])} 与 ETIC_EMBED_DIM={settings.embed_dim} 不一致，"
            "请对齐配置后重试。"
        )

    with store.connect(settings) as conn:
        store.ensure_schema(conn, settings.embed_dim)
        count = store.ingest(conn, docs, vectors)
    print(f"灌库完成：{count} 条已写入 {settings.database_url}")


if __name__ == "__main__":
    asyncio.run(main())
