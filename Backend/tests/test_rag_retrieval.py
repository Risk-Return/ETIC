import json

import pytest

from app.config import Settings
from app.models import DivinationBoard
from app.rag.retrieval import (
    _exact_keys,
    render_grounding,
    retrieve_grounding,
)
from tests.conftest import FIXTURES


def _board() -> DivinationBoard:
    return DivinationBoard.model_validate(
        json.loads((FIXTURES / "board.json").read_text(encoding="utf-8"))
    )


def test_exact_keys_cover_primary_moving_and_changed():
    keys = _exact_keys(_board())
    assert ("山火贲", "judgment", None) in keys
    assert ("山火贲", "line", 1) in keys
    assert ("山火贲", "line", 4) in keys
    assert ("火山旅", "judgment", None) in keys


async def test_retrieve_disabled_returns_empty():
    settings = Settings(mock_llm=True, rag_enabled=False)
    assert await retrieve_grounding(settings, _board()) == []


@pytest.mark.asyncio
async def test_retrieve_grounding_includes_classical_text(rag_db):
    docs = await retrieve_grounding(rag_db, _board())
    refs = {d.ref for d in docs}
    # 本卦卦辞、两条动爻爻辞、变卦卦辞必在其中。
    assert "《山火贲》卦辞" in refs
    assert "《山火贲》初爻" in refs
    assert "《山火贲》四爻" in refs
    assert "《火山旅》卦辞" in refs
    # 原文片段确实拼进可注入文本。
    text = render_grounding(docs)
    assert "贲其趾" in text
    assert "经文参考" in text


@pytest.mark.asyncio
async def test_retrieve_failure_is_graceful(monkeypatch):
    settings = Settings(
        mock_llm=True,
        rag_enabled=True,
        database_url="postgresql://invalid:invalid@127.0.0.1:1/none",
    )
    # DB 不可达时应静默退化为空，不抛异常。
    assert await retrieve_grounding(settings, _board()) == []
