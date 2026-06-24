# ETIC 解读后端（M4）

六爻盘面 → LLM 流式解读 + 多轮追问。**只负责解读，隐藏 LLM key**；排盘引擎在端上离线运行（见 `Packages/DivinationEngine`）。

严格遵守 [DESIGN §4](../docs/DESIGN.md) 分层：盘面由引擎确定性算定，LLM 只解读、不计算、不改盘。

## 运行

```bash
cd Backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # 填入 ETIC_LLM_API_KEY；留空则自动 mock
uvicorn app.main:app --reload --port 8000
```

健康检查：`curl localhost:8000/healthz` →（无 key 时）`{"status":"ok","mock":true,...}`。

## 接口

所有解读接口返回 **SSE 流**（`text/event-stream`），每个事件 `data: {"delta":"..."}`，错误为 `data: {"error":"..."}`，结束为 `data: [DONE]`。

### `POST /v1/interpret` — 首轮解读
请求体：
```json
{ "board": { /* DivinationEngine 的 DivinationBoard 契约 JSON */ } }
```

### `POST /v1/chat` — 多轮追问（同一盘面上下文）
```json
{
  "board": { /* 同上 */ },
  "messages": [
    { "role": "user", "content": "大概什么时候应？" },
    { "role": "assistant", "content": "……" },
    { "role": "user", "content": "对考学具体怎么说？" }
  ]
}
```
约束：`messages` 非空且最后一条须为 `user`。

### 示例
```bash
curl -N -X POST localhost:8000/v1/interpret \
  -H 'Content-Type: application/json' \
  -d @tests/fixtures/board.json   # 注意需包成 {"board": ...}
```

## 配置（环境变量，前缀 `ETIC_`）

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `ETIC_LLM_BASE_URL` | `https://api.deepseek.com/v1` | OpenAI 兼容 base url |
| `ETIC_LLM_MODEL` | `deepseek-chat` | 模型名 |
| `ETIC_LLM_API_KEY` | 空 | 留空 → 自动 mock |
| `ETIC_LLM_TEMPERATURE` | `0.7` | |
| `ETIC_MOCK_LLM` | `false` | 强制 mock（无需真实 key） |
| `ETIC_MAX_HISTORY_MESSAGES` | `20` | 多轮携带的历史上限 |

Provider 切换只需改 `base_url`/`model`/`key`（DeepSeek / 通义 / OpenAI 等 OpenAI 兼容端点均可）。

## 测试

```bash
pip install -r requirements-dev.txt
pytest            # 全程 mock，无需真实 key
```

`tests/fixtures/board.json` 由引擎真实排盘生成（山火贲→火山旅，含动爻），保证盘面契约与引擎一致。
