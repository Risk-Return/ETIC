"""ETIC 解读后端：六爻盘面 → LLM 流式解读 + 多轮追问。

排盘引擎在端上离线运行；本服务只负责"解读"，隐藏 LLM key。
M6 起增加账号 & 计费：Sign in with Apple、额度扣减、追问限制。
"""

import json
import logging
import uuid
from typing import AsyncIterator, Optional

from fastapi import Depends, FastAPI, HTTPException
from fastapi.responses import StreamingResponse

# Ensure application-level INFO logs are visible.
logging.basicConfig(level=logging.INFO, format="%(levelname)s [%(name)s] %(message)s")

from .account import (
    check_and_deduct_reading_credit,
    check_and_increment_question,
)
from .auth import get_current_user_id, require_user_id
from .config import Settings, get_settings
from .iap import router as iap_router
from .llm import LLMError, stream_completion
from .moderation import ModerationResult, moderate
from .models import (
    ChatRequest,
    GroundingItem,
    GroundingRequest,
    GroundingResponse,
    InterpretRequest,
)
from .prompt import build_chat_messages, build_interpret_messages
from .rag.retrieval import render_grounding, retrieve_grounding

# Account & billing router
from .account import router as account_router

app = FastAPI(title="ETIC 解读后端", version="0.2.0")
app.include_router(iap_router)
app.include_router(account_router)


@app.get("/healthz")
async def healthz() -> dict:
    settings = get_settings()
    return {
        "status": "ok",
        "mock": settings.use_mock,
        "model": settings.llm_model if not settings.use_mock else "mock",
        "rag": settings.rag_enabled,
        "embeddings": (
            "mock" if settings.use_mock_embeddings else settings.embed_model
        ),
        "billing": settings.billing_enabled,
        "moderation": settings.moderation_enabled,
    }


def _sse_event(data: dict) -> str:
    return "data: " + json.dumps(data, ensure_ascii=False) + "\n\n"


def _check_moderation(settings: Settings, text: str | None, locale: str | None) -> ModerationResult:
    """审核用户文本。关闭审核时一律放行。"""

    if not settings.moderation_enabled:
        return ModerationResult(action="allow")
    return moderate(text, locale)


async def _refusal_stream(result: ModerationResult) -> AsyncIterator[str]:
    """高危内容被拦截：不调用 LLM，直接以 SSE 流回本地化安全提示，客户端照常渲染。"""

    yield _sse_event({"blocked": True, "category": result.category})
    if result.message:
        yield _sse_event({"delta": result.message})
    yield "data: [DONE]\n\n"


def _refusal_response(result: ModerationResult) -> StreamingResponse:
    return StreamingResponse(
        _refusal_stream(result),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


async def _sse_stream(settings: Settings, messages: list[dict]) -> AsyncIterator[str]:
    try:
        async for kind, text in stream_completion(settings, messages):
            # reasoning = 思考过程（客户端可折叠/展示「思考中」）；content = 正文解读。
            yield _sse_event({"reasoning": text} if kind == "reasoning" else {"delta": text})
    except LLMError as exc:
        yield _sse_event({"error": str(exc)})
    yield "data: [DONE]\n\n"


def _sse_response(settings: Settings, messages: list[dict]) -> StreamingResponse:
    return StreamingResponse(
        _sse_stream(settings, messages),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


async def _grounding_text(settings: Settings, board) -> str | None:
    docs = await retrieve_grounding(settings, board)
    return render_grounding(docs) if docs else None


@app.post("/v1/interpret")
async def interpret(
    req: InterpretRequest,
    user_id: Optional[uuid.UUID] = Depends(get_current_user_id),
    settings: Settings = Depends(get_settings),
) -> StreamingResponse:
    """首轮解读：基于盘面给整体断语（SSE 流式）。

    billing_enabled 时需鉴权并扣减额度；关闭时兼容旧流程（不鉴权）。
    """

    # 内容审核先行：高危问题直接拒绝，不鉴权、不扣费、不调用 LLM。
    mod = _check_moderation(settings, req.board.question, req.locale)
    if mod.blocked:
        return _refusal_response(mod)

    if settings.billing_enabled:
        if user_id is None:
            raise HTTPException(status_code=401, detail="Authentication required")
        board_dict = req.board.model_dump()
        error = check_and_deduct_reading_credit(settings, user_id, board_dict)
        if error:
            raise HTTPException(status_code=402, detail=error)

    grounding = await _grounding_text(settings, req.board)
    messages = build_interpret_messages(
        req.board, grounding, locale=req.locale, caution_note=mod.caution_note
    )
    return _sse_response(settings, messages)


@app.post("/v1/grounding")
async def grounding(req: GroundingRequest) -> GroundingResponse:
    """经文检索：按盘面返回本卦/动爻/变卦相关经文，供客户端展示「经文参考」。

    与解读流（/v1/interpret、/v1/chat）分离；rag 关闭或库不可达时返回空列表。
    """

    settings = get_settings()
    docs = await retrieve_grounding(settings, req.board)
    items = [
        GroundingItem(
            ref=d.ref,
            hexagramName=d.hexagram_name,
            hexagramShort=d.hexagram_short,
            docType=d.doc_type,
            linePosition=d.line_position,
            content=d.content,
        )
        for d in docs
    ]
    return GroundingResponse(enabled=settings.rag_enabled, items=items)


@app.post("/v1/chat")
async def chat(
    req: ChatRequest,
    user_id: Optional[uuid.UUID] = Depends(get_current_user_id),
    settings: Settings = Depends(get_settings),
) -> StreamingResponse:
    """多轮追问：同一盘面上下文中延展（SSE 流式）。

    billing_enabled 时需鉴权并检查追问次数限制；关闭时兼容旧流程。
    """

    if not req.messages:
        raise HTTPException(status_code=422, detail="messages 不能为空")
    if req.messages[-1].role != "user":
        raise HTTPException(status_code=422, detail="最后一条消息必须是用户提问")

    # 审核本轮追问文本（同时参考盘面所问，以覆盖高危上下文）。
    mod = _check_moderation(
        settings, req.messages[-1].content or req.board.question, req.locale
    )
    if mod.blocked:
        return _refusal_response(mod)

    if settings.billing_enabled:
        if user_id is None:
            raise HTTPException(status_code=401, detail="Authentication required")
        board_dict = req.board.model_dump()
        error = check_and_increment_question(settings, user_id, board_dict)
        if error:
            raise HTTPException(status_code=429, detail=error)

    history = [m.model_dump() for m in req.messages[-settings.max_history_messages:]]
    grounding = await _grounding_text(settings, req.board)
    messages = build_chat_messages(
        req.board, history, grounding, locale=req.locale, caution_note=mod.caution_note
    )
    return _sse_response(settings, messages)
