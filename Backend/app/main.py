"""ETIC 解读后端：六爻盘面 → LLM 流式解读 + 多轮追问。

排盘引擎在端上离线运行；本服务只负责"解读"，隐藏 LLM key。
"""

import json
from typing import AsyncIterator

from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse

from .config import Settings, get_settings
from .llm import LLMError, stream_completion
from .models import ChatRequest, InterpretRequest
from .prompt import build_chat_messages, build_interpret_messages

app = FastAPI(title="ETIC 解读后端", version="0.1.0")


@app.get("/healthz")
async def healthz() -> dict:
    settings = get_settings()
    return {
        "status": "ok",
        "mock": settings.use_mock,
        "model": settings.llm_model if not settings.use_mock else "mock",
    }


def _sse_event(data: dict) -> str:
    return "data: " + json.dumps(data, ensure_ascii=False) + "\n\n"


async def _sse_stream(settings: Settings, messages: list[dict]) -> AsyncIterator[str]:
    try:
        async for delta in stream_completion(settings, messages):
            yield _sse_event({"delta": delta})
    except LLMError as exc:
        yield _sse_event({"error": str(exc)})
    yield "data: [DONE]\n\n"


def _sse_response(settings: Settings, messages: list[dict]) -> StreamingResponse:
    return StreamingResponse(
        _sse_stream(settings, messages),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@app.post("/v1/interpret")
async def interpret(req: InterpretRequest) -> StreamingResponse:
    """首轮解读：基于盘面给整体断语（SSE 流式）。"""

    settings = get_settings()
    messages = build_interpret_messages(req.board)
    return _sse_response(settings, messages)


@app.post("/v1/chat")
async def chat(req: ChatRequest) -> StreamingResponse:
    """多轮追问：同一盘面上下文中延展（SSE 流式）。"""

    settings = get_settings()
    if not req.messages:
        raise HTTPException(status_code=422, detail="messages 不能为空")
    if req.messages[-1].role != "user":
        raise HTTPException(status_code=422, detail="最后一条消息必须是用户提问")

    history = [m.model_dump() for m in req.messages[-settings.max_history_messages:]]
    messages = build_chat_messages(req.board, history)
    return _sse_response(settings, messages)
