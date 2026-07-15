"""LLM 客户端：OpenAI 兼容协议的流式转发 + mock 桩。

后端隐藏 API key，客户端只与本服务交互。
"""

import json
from typing import AsyncIterator, Literal

import httpx

from .config import Settings

# 流式产出的分片类型：reasoning = 模型思考过程；content = 正式解读正文。
Chunk = tuple[Literal["reasoning", "content"], str]

MOCK_REPLY = (
    "【整体断语】\n"
    "（mock 模式）后端未配置 LLM key，以下为占位文本，用于联调流式与多轮对话。"
    "盘面已由引擎确定性算出，真实解读将基于世应、用神、动爻与旺衰展开。\n\n"
    "【用神分析】\n用神旺衰与生克需结合月建日建判断。\n\n"
    "【关键爻与动爻】\n动爻牵动变卦，影响应期与吉凶走向。\n\n"
    "【应期推测】\n以月建日建与旬空给出区间，而非绝对时点。\n\n"
    "【建议】\n顺势而为，关注用神受生受克之机。\n\n"
    "【免责声明】\n传统文化娱乐参考，非科学预测，请勿据此做医疗、法律、财务等重大决策。"
)


class LLMError(Exception):
    """上游 LLM 调用失败。"""


async def _stream_mock(messages: list[dict]) -> AsyncIterator[Chunk]:
    # 按句切片模拟流式 token。
    for chunk in MOCK_REPLY.splitlines(keepends=True):
        yield ("content", chunk)


async def _stream_openai_compatible(
    settings: Settings, messages: list[dict]
) -> AsyncIterator[Chunk]:
    payload = {
        "model": settings.llm_model,
        "messages": messages,
        "temperature": settings.llm_temperature,
        "stream": True,
    }
    headers = {
        "Authorization": f"Bearer {settings.llm_api_key}",
        "Content-Type": "application/json",
    }
    url = settings.llm_base_url.rstrip("/") + "/chat/completions"

    async with httpx.AsyncClient(
        timeout=httpx.Timeout(
            connect=10.0,
            read=settings.llm_timeout_seconds,
            write=30.0,
            pool=10.0,
        ),
    ) as client:
        async with client.stream("POST", url, json=payload, headers=headers) as resp:
            if resp.status_code >= 400:
                body = (await resp.aread()).decode("utf-8", "replace")
                raise LLMError(f"上游 LLM {resp.status_code}: {body[:500]}")
            async for raw_line in resp.aiter_lines():
                line = raw_line.strip()
                if not line or not line.startswith("data:"):
                    continue
                data = line[len("data:"):].strip()
                if data == "[DONE]":
                    return
                try:
                    obj = json.loads(data)
                except json.JSONDecodeError:
                    continue
                choices = obj.get("choices") or []
                if not choices:
                    continue
                delta = choices[0].get("delta") or {}
                # 推理模型（如 deepseek-v4-pro）先产出 reasoning_content，
                # 单独转发以便客户端即时显示「思考中」，避免正文前长时间静默触发超时。
                reasoning = delta.get("reasoning_content")
                if reasoning:
                    yield ("reasoning", reasoning)
                content = delta.get("content")
                if content:
                    yield ("content", content)


async def stream_completion(
    settings: Settings, messages: list[dict]
) -> AsyncIterator[Chunk]:
    """流式产出解读分片：("reasoning", ...) 为思考过程，("content", ...) 为正文。"""

    if settings.use_mock:
        async for chunk in _stream_mock(messages):
            yield chunk
    else:
        async for chunk in _stream_openai_compatible(settings, messages):
            yield chunk
