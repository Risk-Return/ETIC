"""盘面 → grounding：检索与本卦/变卦/动爻最相关的周易经文。

六爻断卦最相关的经文是：本卦卦辞、动爻爻辞（动则有言）、变卦卦辞。这些用精确定位
取出；再用问题语义做向量召回补充。检索失败时返回空（不阻断解读，退化为 M4 行为）。
"""

import asyncio
import logging

from ..config import Settings
from ..models import DivinationBoard
from .corpus import Document
from .embeddings import embed_texts
from . import store

logger = logging.getLogger(__name__)


def _exact_keys(board: DivinationBoard) -> list[tuple[str, str, int | None]]:
    keys: list[tuple[str, str, int | None]] = []
    primary = board.primary.name
    keys.append((primary, "judgment", None))
    for pos in sorted(board.movingPositions):
        keys.append((primary, "line", pos))
    if board.changed is not None and board.changed.name:
        keys.append((board.changed.name, "judgment", None))
    return keys


def _query_text(board: DivinationBoard) -> str:
    parts = [board.question or "", board.category or "", board.primary.name]
    if board.changed is not None:
        parts.append(board.changed.name)
    return "；".join(p for p in parts if p)


def _retrieve_sync(settings: Settings, board: DivinationBoard, query_vec) -> list[Document]:
    keys = _exact_keys(board)
    with store.connect(settings) as conn:
        exact = store.fetch_exact(conn, keys)
        hits = store.search(conn, query_vec, settings.rag_top_k, exclude=keys)
    docs = list(exact) + [d for d, _ in hits]
    return docs


async def retrieve_grounding(
    settings: Settings, board: DivinationBoard
) -> list[Document]:
    if not settings.rag_enabled:
        return []
    try:
        vectors = await embed_texts(settings, [_query_text(board)])
        query_vec = vectors[0]
        return await asyncio.to_thread(_retrieve_sync, settings, board, query_vec)
    except Exception as exc:  # noqa: BLE001 - 检索是增强项，失败不应阻断解读
        logger.warning("RAG 检索失败，退化为无 grounding 解读：%s", exc)
        return []


def render_grounding(docs: list[Document]) -> str:
    """把检索到的经文拼成可注入 Prompt 的中文片段。"""

    lines = ["【经文参考】（仅供引用，不得改动盘面）"]
    for d in docs:
        lines.append(f"- {d.content}")
    return "\n".join(lines)
