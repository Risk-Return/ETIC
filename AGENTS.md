# AGENTS.md

本文件为 Claude Code、Devin 等智能体提供 ETIC 项目的导航与约束。**动手前请先读完本文件**，再视任务深入相应目录的 README 与 `docs/DESIGN.md`。

---

## 1. 项目目的

ETIC 是一款基于中国易经（以**六爻纳甲**为主线）的 iOS 占卜应用。

它要解决的核心问题：**让术数计算可信、可复现、可审计，同时让解读自然、个性化**。为此采用一条贯穿全项目的最高原则——

> **确定性术数计算与 LLM 解读严格分层。**
> 起卦、排盘、纳甲、世应、六亲、六神、动变爻、旬空、旺衰、取用神等**全部由本地确定性引擎完成**，输出结构化盘面 JSON；大模型**只对这份盘面做解读与多轮对话，绝不参与任何计算，也不得改动盘面数据**。

任何改动都不得违反这条原则。若某需求看似需要让 LLM 计算/改盘，应改为扩展引擎或调整数据契约，而不是把计算下放给模型。

---

## 2. 设计文档位置（先读这些）

| 文档 | 内容 |
| --- | --- |
| `docs/DESIGN.md` | **权威**架构、分层、排盘九步流水线、动画设计、LLM 选型、数据流、开发计划（M0–M7）、风险对策。任何设计问题以此为准。 |
| `README.md`（根） | 项目概述、仓库结构、引擎说明、代码规范。 |
| `App/README.md` | iOS App 结构、构建运行方式（xcodegen + Xcode）、各模块说明。 |
| `Backend/README.md` | 后端解读代理的安装、接口契约、配置、测试。 |
| `docs/TESTING-M2-M3.md` | M2/M3 在 macOS+Xcode 上的手动测试清单。 |

设计相关引用请标注出处章节（如 `DESIGN.md §4.2`）。

---

## 3. 代码结构

```
ETIC/
├── docs/                          # 设计与测试文档
├── Packages/DivinationEngine/     # ① 确定性排盘引擎（纯 Swift，离线，仅 Foundation）
│   ├── Sources/DivinationEngine/
│   │   ├── Model/                 # 五行/阴阳/干支/八卦/64卦/六亲/六神/旺衰/爻 领域模型
│   │   ├── Data/                  # 纳甲表、64卦名、八宫世应、二十四节气表（预设静态数据）
│   │   ├── Calendar/              # 公历 → 干支历换算（立春换岁/节换月/五虎遁/五鼠遁）
│   │   ├── Casting/               # 起卦：铜钱/数字/时间/随机/梅花（随机源可注入以复现）
│   │   └── Engine/                # 盘面数据契约 Board.swift + 排盘九步流水线
│   └── Tests/                     # 静态表快照 + 经典卦例端到端 + 历法基准 + 概率分布
├── App/ETIC/                      # ② iOS 客户端（SwiftUI，iOS 17+）
│   ├── Casting/                   # 起卦页（方法/问题/事项/时间）
│   ├── Ritual/                    # M3 占卜动画（罗盘/铜钱/水墨成卦/摇一摇/触觉/设置）
│   ├── Board/                     # 排盘可视化（卦名/盘面表/四柱旬空/用神）
│   ├── Interpret/                 # M4 LLM 解读对话页（流式气泡 + 多轮追问 + 经文参考）
│   ├── History/                   # M6 本地历史/收藏（SwiftData 持久化卡例与对话）
│   ├── Encyclopedia/              # 卦象百科：64 卦经文浏览（内置周易 JSON，离线只读）
│   ├── Services/                  # DivinationService（引擎桥接）、LLMService（后端 SSE）
│   └── Theme/                     # 水墨主题
├── Backend/                       # ③ LLM 解读代理 + RAG（FastAPI，Python 3.12）
│   ├── app/                       # config / models / prompt / llm / main
│   │   └── rag/                   # M5：周易经文语料 + embeddings + pgvector + 检索
│   │       └── data/zhouyi.json   # 公有领域周易经文（64卦卦辞+384爻辞）
│   ├── scripts/                   # build_corpus.py（生成语料）、ingest.py（灌库）
│   ├── docker-compose.yml         # 本地 Postgres + pgvector
│   └── tests/                     # pytest（含引擎真实排盘生成的 board.json fixture；RAG 集成测试无库时 skip）
└── scripts/gen_fixtures.py        # 用 sxtwl 离线生成节气表与历法基准（开发工具）
```

### 三层边界（务必遵守）

- **引擎层 `Packages/DivinationEngine`**：纯函数、确定性、离线。**禁止**依赖 SwiftUI / UIKit / 网络 / LLM。相同输入恒得相同盘面。
- **客户端 `App/ETIC`**：只读消费引擎输出的 `DivinationBoard`，**不做任何术数计算**。通过 `Services/` 桥接引擎与后端。
- **后端 `Backend`**：接收端上算好的盘面 JSON，组装 System Prompt，经 OpenAI 兼容协议流式返回解读。**隐藏 LLM key，客户端不直连模型、不持有 key。**

### 唯一数据契约

`DivinationBoard`（`Packages/DivinationEngine/Sources/DivinationEngine/Engine/Board.swift`，schema **v1.0.0**）是引擎 ↔ UI ↔ LLM 之间的**唯一接口，已冻结**。后端 `Backend/app/models.py` 的 Pydantic 模型须与之保持一致。改动契约需同步引擎、客户端、后端、fixture 并更新 schema 版本。

---

## 4. 构建与测试

### 引擎（Linux / macOS 均可，CI 跑这个）
```bash
cd Packages/DivinationEngine
swift build
swift test          # 23 用例：静态表快照 + 经典卦例 + 历法基准（比对 sxtwl）+ 铜钱概率分布
```
GitHub Actions（`swift:5.10` 容器）在每次 push / PR 上自动执行 `swift build` + `swift test`。**CI 目前只构建引擎包**，不构建 iOS、不跑后端。

### iOS App（需 macOS + Xcode，本仓库 CI 不覆盖）
```bash
cd App
xcodegen generate
open ETIC.xcodeproj   # iOS 17+ 模拟器/真机（M6 起用 SwiftData，最低 iOS 17）
```
摇一摇与触觉反馈仅真机可测。手动测试清单见 `docs/TESTING-M2-M3.md`。

### 后端（Python 3.12）
```bash
cd Backend
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
pytest                                   # prompt 组装 + SSE 接口 + RAG（语料/embeddings/检索）
uvicorn app.main:app --port 8000         # 本地起服务；无 key 时自动 mock，无需真实 key
# RAG（M5）：docker compose up -d 起 pgvector → python scripts/ingest.py 灌库 → 设 ETIC_RAG_ENABLED=true
```
接口：`POST /v1/interpret`（首轮解读）、`POST /v1/chat`（多轮追问）均 SSE 流式（`data:{"delta":...}` → `[DONE]`）；`GET /healthz` 健康检查。开启 RAG 后解读前检索周易经文 grounding。详见 `Backend/README.md`。

---

## 5. 开发约定

- **分支**：`devin/<timestamp>-<topic>`；不直接推 `main`/`master`。
- **PR**：走 `.github/PULL_REQUEST_TEMPLATE.md` 模板；**CI 必绿方可合入**。
- **最小改动**：聚焦任务范围，勿动无关文件；不为通过测试而修改测试或硬编码绕过。
- **术数规则改动**：须附经典卦例或权威出处，并补充/更新引擎测试。
- **密钥安全**：LLM key 等机密**只经后端、走 `.env`（参考 `Backend/.env.example`），绝不写入前端代码或提交进 git**。`Backend/.env` 已在 `.gitignore`。
- **注释/风格**：跟随既有代码风格，倾向简洁；中文文案与枚举值需与现有代码核对一致。
- **里程碑**：已完成 M0–M5（引擎 / 起卦排盘 UI / 动画 / LLM 解读 / 多轮追问 + RAG 周易经文 grounding）。M6（历史 / 账号 / 计费 / 合规）进行中：已完成**本地历史/收藏**（SwiftData，iOS 17+）、**卦象百科**、**账号 + StoreKit 计费**、**内容安全审核**（后端 `app/moderation.py` 双语硬拦截 + 敏感分级，配合 `SYSTEM_PROMPT` 软性约束）。详见 `docs/DESIGN.md` 开发计划。

---

## 6. 智能体注意事项

- 本机环境为 **Linux 无 Xcode**：SwiftUI 代码可写、可静态审阅，但**无法在此编译/运行/截图**；iOS 验证需用户在本地 Xcode 完成。引擎（纯 Swift）与后端（Python）可在 Linux 上真实编译并测试。
- 改动前先确认所属层，避免跨层泄漏（例如把计算写进 UI 或后端、让 LLM 改盘）。
- 涉及盘面字段时，以 `Board.swift` 的 `DivinationBoard` 为准，不要臆测字段名。
