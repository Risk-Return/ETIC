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
async def test_chat_rejects_empty_messages(client, board_json):
    resp = await client.post("/v1/chat", json={"board": board_json, "messages": []})
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_chat_requires_last_user(client, board_json):
    payload = {
        "board": board_json,
        "messages": [{"role": "assistant", "content": "..."}],
    }
    resp = await client.post("/v1/chat", json=payload)
    assert resp.status_code == 422
