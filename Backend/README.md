# ETIC 解读后端（M4 + M5）

六爻盘面 → LLM 流式解读 + 多轮追问 + 周易经文 RAG grounding。**只负责解读，隐藏 LLM key**；排盘引擎在端上离线运行（见 `Packages/DivinationEngine`）。

严格遵守 [DESIGN §4](../docs/DESIGN.md) 分层：盘面由引擎确定性算定，LLM 只解读、不计算、不改盘。

## 运行

```bash
cd Backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # 填入 ETIC_LLM_API_KEY；留空则自动 mock
uvicorn app.main:app --reload --port 18000
```

健康检查：`curl localhost:8000/healthz` →（无 key 时）`{"status":"ok","mock":true,...}`。

## 接口

所有解读接口返回 **SSE 流**（`text/event-stream`），每个事件 `data: {"delta":"..."}`，错误为 `data: {"error":"..."}`，结束为 `data: [DONE]`。被内容审核拦截时首个事件为 `data: {"blocked":true,"category":"..."}`，随后是本地化安全提示的 `delta`（不调用 LLM）。

`interpret` / `chat` 均可选传 `"locale"`（如 `"zh-Hans"` / `"en"`），用于内容审核拒绝文案与解读作答语言；缺省时按文本是否含中日韩文字自动判定。

### `POST /v1/interpret` — 首轮解读
请求体：
```json
{ "board": { /* DivinationEngine 的 DivinationBoard 契约 JSON */ }, "locale": "zh-Hans" }
```

### `POST /v1/chat` — 多轮追问（同一盘面上下文）
```json
{
  "board": { /* 同上 */ },
  "locale": "zh-Hans",
  "messages": [
    { "role": "user", "content": "大概什么时候应？" },
    { "role": "assistant", "content": "……" },
    { "role": "user", "content": "对考学具体怎么说？" }
  ]
}
```
约束：`messages` 非空且最后一条须为 `user`。

### 内容安全审核（M6）
起卦问题 / 追问文本在进入 LLM 前先过确定性审核（`app/moderation.py`，中英双语），分三级：
- **拦截（block）**：自伤轻生、伤害他人 / 暴力、违法制毒制爆、涉未成年不当内容 → 直接拒绝、不鉴权不扣费不调用 LLM，回本地化安全提示（自伤类附危机求助信息）。
- **敏感（caution）**：重病绝症 / 诉讼判决 / 投资必涨等 → 放行，但向 Prompt 注入更强的"去绝对化 + 免责 + 建议咨询专业人士"约束。
- **放行（allow）**：其余正常解读。

由 `ETIC_MODERATION_ENABLED`（默认 `true`）控制；关闭时回退旧流程。此为**硬性管理**，与 `SYSTEM_PROMPT` 中的安全**软性约束**互补。

### `POST /v1/grounding` — 经文检索（非流式，供客户端展示「经文参考」）
请求体 `{ "board": { /* 同上 */ } }`，返回按本卦/动爻/变卦检索到的周易原文：
```json
{
  "enabled": true,
  "items": [
    { "ref": "《山火贲》卦辞", "hexagramName": "山火贲", "hexagramShort": "贲",
      "docType": "judgment", "linePosition": null, "content": "《山火贲》卦辞：亨。小利有所往。" }
  ]
}
```
与解读流分离，便于客户端单独渲染引用原文；`ETIC_RAG_ENABLED=false` 或库不可达时 `enabled=false`、`items=[]`（优雅退化，不影响解读）。

### 邮箱验证码登录

- `POST /v1/auth/email/code`：请求体 `{ "email": "user@example.com" }`。生成 6 位验证码经腾讯企业邮 SMTP 发送，返回 `{ "success": true, "cooldownSeconds": 60, "message": "..." }`。同邮箱冷却期内重复请求返回 `429`；未配置 SMTP 时自动 mock（验证码只打日志）。
- `POST /v1/auth/email/verify`：请求体 `{ "email": "...", "code": "123456" }`。验证通过后按邮箱创建/检索用户，返回与 Apple 登录相同的 `{ "sessionToken": "...", "account": { ... } }`。验证码 10 分钟有效、最多试错 5 次、验证后一次性消费。
- 账号统一：同一邮箱在 Apple 登录（Apple 返回了邮箱）与邮箱验证码登录之间共享同一账号，额度、订阅与 IAP 归属一致（IAP 通过会话 JWT 的 user_id 绑定，购买时 App 侧同时携带 `appAccountToken=userId`）。

### 示例
```bash
curl -N -X POST localhost:18000/v1/interpret \
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
| `ETIC_RAG_ENABLED` | `false` | 开启卦爻辞检索 grounding（需先灌库） |
| `ETIC_DATABASE_URL` | `postgresql://etic:etic@localhost:5432/etic` | pgvector 库 |
| `ETIC_EMBED_BASE_URL` | 空→回退 LLM | embeddings 的 OpenAI 兼容 base url |
| `ETIC_EMBED_MODEL` | `text-embedding-3-small` | embeddings 模型 |
| `ETIC_EMBED_API_KEY` | 空→回退 LLM key | 留空且无 LLM key → mock 向量 |
| `ETIC_EMBED_DIM` | `256` | 向量维度（mock 与真实须一致） |
| `ETIC_RAG_TOP_K` | `4` | 向量召回条数 |
| `ETIC_RAG_INCLUDE_TUAN` | `false` | 是否附带彖辞 |
| `ETIC_SMTP_HOST` | `smtp.exmail.qq.com` | 腾讯企业邮 SMTP 主机 |
| `ETIC_SMTP_PORT` | `465` | SMTP SSL 端口 |
| `ETIC_SMTP_USER` | 空 | 发信邮箱地址（留空 → mock 发信） |
| `ETIC_SMTP_PASSWORD` | 空 | 企业邮客户端专用密码（留空 → mock 发信） |
| `ETIC_SMTP_FROM_NAME` | `ETIC` | 发件人显示名 |
| `ETIC_EMAIL_CODE_TTL_MINUTES` | `10` | 验证码有效期（分钟） |
| `ETIC_EMAIL_CODE_COOLDOWN_SECONDS` | `60` | 重发冷却（秒） |
| `ETIC_EMAIL_CODE_MAX_ATTEMPTS` | `5` | 单码最大试错次数 |

Provider 切换只需改 `base_url`/`model`/`key`（DeepSeek / 通义 / OpenAI 等 OpenAI 兼容端点均可）。

## RAG（卦爻辞 grounding，M5）

开启后，解读前按**本卦卦辞、动爻爻辞、变卦卦辞**精确定位 + 问题语义向量召回，把周易经文原文拼入 Prompt，要求 LLM 援引原文、降低幻觉。语料为公有领域《周易》经文（64 卦卦辞 + 384 爻辞），见 `app/rag/data/zhouyi.json`（由 `scripts/build_corpus.py` 生成，以引擎卦名为主键）。

```bash
docker compose up -d            # 起 Postgres + pgvector
cp .env.example .env           # 设 ETIC_RAG_ENABLED=true（embeddings 可留 mock）
python scripts/ingest.py       # 灌库：64 卦 → 448 条文档向量化入库
uvicorn app.main:app --port 18000
```

无 embeddings key 时用**确定性 mock 向量**，可完全离线灌库与联调；精确定位的本卦/动爻/变卦经文不依赖向量质量，故 mock 下 grounding 仍准确。切换真实 embeddings provider 后需把 `ETIC_EMBED_DIM` 调成对应维度（如 `text-embedding-3-small` 为 1536）并重新 `ingest`。

`healthz` 会回报 `rag` 与 `embeddings` 状态。

## 测试

```bash
pip install -r requirements-dev.txt
pytest            # 全程 mock，无需真实 key
```

RAG 集成测试需本地 pgvector（`docker compose up -d`）；**数据库不可用时这些用例自动 skip**，其余用例照常通过。

`tests/fixtures/board.json` 由引擎真实排盘生成（山火贲→火山旅，含动爻），保证盘面契约与引擎一致。
