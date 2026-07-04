"""文本向量化：OpenAI 兼容 /embeddings + 本地确定性 mock 降级。

延续 M4 的 mock 哲学：无 embeddings key 时用确定性本地向量，使整条 RAG 流水线
（灌库 / 检索 / 测试）可离线跑通；配置真实 provider 后即走在线 embeddings。
mock 与真实向量维度须一致（settings.embed_dim），切换后需重新灌库。
"""

import hashlib
import math
from typing import Sequence

import httpx

from ..config import Settings


class EmbeddingError(Exception):
    """上游 embeddings 调用失败。"""


def _mock_embed_one(text: str, dim: int) -> list[float]:
    """确定性本地向量：按字符 + 2-gram 散列入桶后 L2 归一化。

    共享字符 / 词的文本会得到相近向量，使 mock 检索具备弱语义信号。
    """
    vec = [0.0] * dim
    tokens = list(text) + [text[i : i + 2] for i in range(len(text) - 1)]
    for tok in tokens:
        h = hashlib.md5(tok.encode("utf-8")).digest()
        idx = int.from_bytes(h[:4], "big") % dim
        sign = 1.0 if h[4] & 1 else -1.0
        vec[idx] += sign
    norm = math.sqrt(sum(v * v for v in vec)) or 1.0
    return [v / norm for v in vec]


_EMBED_BATCH_SIZE = 10


async def _embed_openai_compatible(
    settings: Settings, texts: Sequence[str]
) -> list[list[float]]:
    url = settings.effective_embed_base_url.rstrip("/") + "/embeddings"
    headers = {
        "Authorization": f"Bearer {settings.effective_embed_api_key}",
        "Content-Type": "application/json",
    }
    all_vectors: list[list[float]] = []
    async with httpx.AsyncClient(timeout=settings.llm_timeout_seconds) as client:
        for i in range(0, len(texts), _EMBED_BATCH_SIZE):
            batch = texts[i : i + _EMBED_BATCH_SIZE]
            payload = {"model": settings.embed_model, "input": list(batch)}
            resp = await client.post(url, json=payload, headers=headers)
            if resp.status_code >= 400:
                raise EmbeddingError(
                    f"上游 embeddings {resp.status_code}: {resp.text[:500]}"
                )
            data = resp.json().get("data") or []
            if len(data) != len(batch):
                raise EmbeddingError("embeddings 返回条数与输入不一致")
            all_vectors.extend(item["embedding"] for item in data)
    return all_vectors


async def embed_texts(
    settings: Settings, texts: Sequence[str]
) -> list[list[float]]:
    """批量向量化，返回与输入等长的向量列表。"""

    if not texts:
        return []
    if settings.use_mock_embeddings:
        return [_mock_embed_one(t, settings.embed_dim) for t in texts]
    return await _embed_openai_compatible(settings, texts)
