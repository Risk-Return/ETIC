import math

import pytest

from app.config import Settings
from app.rag.embeddings import embed_texts


@pytest.fixture
def mock_settings() -> Settings:
    return Settings(mock_llm=True, embed_dim=256)


async def test_mock_embeddings_deterministic_and_unit_norm(mock_settings):
    a = await embed_texts(mock_settings, ["贲其趾，舍车而徒"])
    b = await embed_texts(mock_settings, ["贲其趾，舍车而徒"])
    assert a == b  # 确定性
    assert len(a[0]) == mock_settings.embed_dim
    assert math.isclose(math.sqrt(sum(x * x for x in a[0])), 1.0, rel_tol=1e-6)


async def test_mock_embeddings_similarity_signal(mock_settings):
    [v_same1, v_same2, v_diff] = await embed_texts(
        mock_settings,
        ["白马翰如，匪寇婚媾", "白马翰如，匪寇婚媾相近", "潜龙勿用见龙在田"],
    )

    def cos(x, y):
        return sum(a * b for a, b in zip(x, y))

    # 共享更多字符的文本，向量相似度更高。
    assert cos(v_same1, v_same2) > cos(v_same1, v_diff)


async def test_empty_input_returns_empty(mock_settings):
    assert await embed_texts(mock_settings, []) == []
