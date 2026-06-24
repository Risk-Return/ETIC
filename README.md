# ETIC · 易经八卦占卜 App

基于中国易经（以**六爻纳甲**为主线）的 iOS 占卜应用。

核心设计原则：**确定性术数计算与 LLM 解读严格分层**——起卦、排盘、生克旺衰等全部由本地确定性引擎完成并输出结构化盘面 JSON；大模型只负责对这份盘面做解读与多轮对话，**不参与任何计算**。

完整架构见 [`docs/DESIGN.md`](docs/DESIGN.md)。

## 仓库结构

```
ETIC/
├── docs/DESIGN.md                 # 架构与开发计划
├── Packages/DivinationEngine/     # 排盘引擎（纯 Swift，离线，可单测）
│   ├── Sources/DivinationEngine/
│   │   ├── Model/                 # 五行/阴阳/干支/八卦/六亲/六神/旺衰/爻 等领域模型
│   │   ├── Data/                  # 纳甲表、64 卦名、八宫世应、节气表（预设数据）
│   │   ├── Calendar/              # 公历→干支历换算
│   │   ├── Casting/               # 起卦（铜钱/数字/时间/随机）
│   │   └── Engine/                # 盘面数据契约 + 排盘流水线
│   └── Tests/                     # 静态表快照 + 经典卦例端到端 + 历法基准 + 概率分布
└── scripts/gen_fixtures.py        # 用 sxtwl 生成节气表与历法测试基准（离线工具）
```

## 排盘引擎（M1）

`DivinationEngine` 是一个纯 Swift Package，仅依赖 Foundation，**不含任何 UI / 网络 / LLM 代码**，可在 Linux / macOS 上离线编译并运行测试。给定起卦结果 + 四柱，输出完整盘面：

- 定卦宫、世应
- 纳甲装爻（干支 → 五行）
- 配六亲（以卦宫五行为「我」）
- 起六神（按日干）
- 标动爻 / 变爻、生成变卦
- 定旬空、旺相休囚死
- 按占问类别取用神建议

输出 [`DivinationBoard`](Packages/DivinationEngine/Sources/DivinationEngine/Engine/Board.swift) —— 引擎与 UI / LLM 之间的**唯一数据契约**（schema v1.0.0）。

### 运行测试

```bash
cd Packages/DivinationEngine
swift build
swift test
```

CI（GitHub Actions，`swift:5.10` 容器）在每次 push / PR 上自动执行 `swift build` + `swift test`。

### 数据来源与可复现性

节气表与历法换算的金标准由 [`sxtwl`](https://pypi.org/project/sxtwl/) 离线生成（见 `scripts/gen_fixtures.py`），引擎用纯 Swift 复现，测试逐项比对。术数规则（纳甲、八宫世应、六亲六神）均有快照与经典卦例断言。

## 代码规范

- 引擎层保持**纯函数、确定性**：相同输入恒得相同盘面，不引入随机性（除显式 `Caster.random`，且支持可注入随机源以复现）。
- 引擎**禁止**依赖 SwiftUI / UIKit / 网络 / LLM。
- 涉及术数规则的改动须附经典卦例或权威出处，并补充测试。
- 分支：`devin/<timestamp>-<topic>`；PR 走模板，CI 必绿方可合入。
