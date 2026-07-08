import json

import httpx
import pytest
from asgi_lifespan import LifespanManager

from app.config import get_settings
from app.main import app


@pytest.fixture(autouse=True)
def force_mock(monkeypatch):
    get_settings.cache_clear()
    monkeypatch.setenv("ETIC_MOCK_LLM", "true")
    monkeypatch.setenv("ETIC_RAG_ENABLED", "false")
    monkeypatch.setenv("ETIC_BILLING_ENABLED", "false")
    yield
    get_settings.cache_clear()


@pytest.fixture
async def client():
    async with LifespanManager(app):
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as c:
            yield c


def _parse_sse_text(body: str) -> str:
    out = []
    for line in body.splitlines():
        line = line.strip()
        if not line.startswith("data:"):
            continue
        data = line[len("data:"):].strip()
        if data == "[DONE]":
            break
        obj = json.loads(data)
        assert "error" not in obj, obj
        out.append(obj.get("delta", ""))
    return "".join(out)


@pytest.mark.asyncio
async def test_healthz(client):
    resp = await client.get("/healthz")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert body["mock"] is True
    # RAG 默认关闭；mock 模式下 embeddings 也走 mock。
    assert body["rag"] is False
    assert body["embeddings"] == "mock"


@pytest.mark.asyncio
async def test_interpret_streams_mock(client, board_json):
    resp = await client.post("/v1/interpret", json={"board": board_json})
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("text/event-stream")
    text = _parse_sse_text(resp.text)
    assert "整体断语" in text
    assert "免责声明" in text


@pytest.mark.asyncio
async def test_chat_streams_mock(client, board_json):
    payload = {
        "board": board_json,
        "messages": [{"role": "user", "content": "对考学具体怎么说？"}],
    }
    resp = await client.post("/v1/chat", json=payload)
    assert resp.status_code == 200
    text = _parse_sse_text(resp.text)
    assert len(text) > 0


@pytest.mark.asyncio
async def test_grounding_disabled_returns_empty(client, board_json):
    # RAG 关闭时优雅退化：enabled=false，items 为空。
    resp = await client.post("/v1/grounding", json={"board": board_json})
    assert resp.status_code == 200
    body = resp.json()
    assert body["enabled"] is False
    assert body["items"] == []


@pytest.mark.asyncio
async def test_grounding_enabled_returns_classical_texts(
    client, board_json, rag_db, monkeypatch
):
    monkeypatch.setenv("ETIC_RAG_ENABLED", "true")
    monkeypatch.setenv("ETIC_EMBED_DIM", "256")
    monkeypatch.setenv("ETIC_DATABASE_URL", rag_db.database_url)
    get_settings.cache_clear()

    resp = await client.post("/v1/grounding", json={"board": board_json})
    assert resp.status_code == 200
    body = resp.json()
    assert body["enabled"] is True
    assert len(body["items"]) > 0
    primary = board_json["primary"]["name"]
    assert any(primary in it["ref"] for it in body["items"])
    assert all(it["content"] for it in body["items"])


@pytest.mark.asyncio
async def test_chat_rejects_empty_messages(client, board_json):
    resp = await client.post("/v1/chat", json={"board": board_json, "messages": []})
    assert resp.status_code == 422


def _parse_sse_events(body: str) -> list[dict]:
    events = []
    for line in body.splitlines():
        line = line.strip()
        if not line.startswith("data:"):
            continue
        data = line[len("data:"):].strip()
        if data == "[DONE]":
            break
        events.append(json.loads(data))
    return events


@pytest.mark.asyncio
async def test_interpret_blocks_self_harm(client, board_json):
    # 高危问题：拦截并回本地化提示，不进入 LLM（无常规解读小标题）。
    board_json["question"] = "我不想活了，想结束自己的生命"
    resp = await client.post(
        "/v1/interpret", json={"board": board_json, "locale": "zh-Hans"}
    )
    assert resp.status_code == 200
    events = _parse_sse_events(resp.text)
    assert events[0].get("blocked") is True
    assert events[0].get("category") == "self_harm"
    text = "".join(e.get("delta", "") for e in events)
    assert "整体断语" not in text
    assert "热线" in text or "援助" in text


@pytest.mark.asyncio
async def test_interpret_block_message_english(client, board_json):
    board_json["question"] = "I want to kill myself"
    resp = await client.post(
        "/v1/interpret", json={"board": board_json, "locale": "en"}
    )
    events = _parse_sse_events(resp.text)
    assert events[0].get("blocked") is True
    text = "".join(e.get("delta", "") for e in events)
    assert "988" in text or "Lifeline" in text


@pytest.mark.asyncio
async def test_interpret_allows_benign_question(client, board_json):
    board_json["question"] = "这个月工作运势如何"
    resp = await client.post("/v1/interpret", json={"board": board_json})
    assert resp.status_code == 200
    text = _parse_sse_text(resp.text)
    assert "整体断语" in text


@pytest.mark.asyncio
async def test_chat_blocks_self_harm(client, board_json):
    payload = {
        "board": board_json,
        "messages": [{"role": "user", "content": "I want to end my life"}],
        "locale": "en",
    }
    resp = await client.post("/v1/chat", json=payload)
    assert resp.status_code == 200
    events = _parse_sse_events(resp.text)
    assert events[0].get("blocked") is True


@pytest.mark.asyncio
async def test_moderation_disabled_passes_through(client, board_json, monkeypatch):
    monkeypatch.setenv("ETIC_MODERATION_ENABLED", "false")
    get_settings.cache_clear()
    board_json["question"] = "我不想活了"
    resp = await client.post("/v1/interpret", json={"board": board_json})
    assert resp.status_code == 200
    text = _parse_sse_text(resp.text)
    # 关闭审核后回退旧流程，走正常 mock 解读。
    assert "整体断语" in text


@pytest.mark.asyncio
async def test_chat_requires_last_user(client, board_json):
    payload = {
        "board": board_json,
        "messages": [{"role": "assistant", "content": "..."}],
    }
    resp = await client.post("/v1/chat", json=payload)
    assert resp.status_code == 422
