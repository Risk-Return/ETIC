# ETIC iOS App（M2 排盘 + M3 动画 + M4 LLM 解读 + M5 经文参考 + M6 历史/收藏 + 卦象百科）

> 最低系统 **iOS 17**（M6 本地历史/收藏使用 SwiftData）。

SwiftUI 客户端。消费 `DivinationEngine` 冻结的 `DivinationBoard` 契约渲染盘面，
并把盘面交给后端解读代理（见 `../Backend`）做流式解读与多轮追问。
客户端**不持有 LLM key、不直连模型**，一律走后端。

## 本地构建（需 macOS + Xcode 15+）

工程用 [XcodeGen](https://github.com/yonyz/XcodeGen) 管理，`.xcodeproj` 不入库。

```bash
brew install xcodegen          # 若未安装
cd App
xcodegen generate              # 由 project.yml 生成 ETIC.xcodeproj
open ETIC.xcodeproj            # 选 iOS 17+ 模拟器运行
```

## 结构

```
App/ETIC
├─ ETICApp.swift            入口（NavigationStack → CastingView）
├─ Theme/InkTheme.swift     水墨主题（宣纸/墨/朱砂/石青 + 五行色 + 衬线字体）
├─ Services/
│  └─ DivinationService.swift  起卦输入 → 引擎 → DivinationBoard（不做术数计算）
├─ Casting/
│  ├─ CastingViewModel.swift   起卦页状态
│  └─ CastingView.swift        方法/问题/类别/时间 + 起卦按钮
├─ Board/
│  ├─ BoardView.swift          排盘页：标题、本卦/变卦切换、盘面表、四柱、用神、解读入口
│  ├─ BoardRowView.swift       单行：六神·六亲·干支·爻象·世应/旬空·旺衰
│  ├─ YaoSymbolView.swift      爻象笔画（阳整笔/阴断笔 + ○× 动爻标记）
│  ├─ FourPillarsView.swift    年月日时四柱 + 旬空
│  ├─ UseGodView.swift         用神建议
│  └─ PreviewData.swift        SwiftUI 预览用确定性样例盘
├─ Services/LLMService.swift   盘面 → 后端 /v1/interpret、/v1/chat（SSE 流式解析）+ /v1/grounding（经文检索）
├─ Interpret/
│  ├─ InterpretationViewModel.swift  解读对话状态机（首轮 + 多轮，携带同一盘面）+ 拉取经文参考
│  └─ InterpretationView.swift       流式打字气泡 + 追问输入框 + 「经文参考」折叠卡片
├─ History/                         M6 本地历史/收藏（SwiftData，iOS 17+）
│  ├─ DivinationRecord.swift        @Model 卦例记录（盘面快照 + 解读对话，内容派生稳定主键）
│  ├─ HistoryStore.swift            读写封装：起卦登记、解读回写、收藏、删除
│  ├─ HistoryListView.swift         列表：时间倒序 + 收藏/事项筛选 + 滑动删除
│  └─ HistoryDetailView.swift       详情：盘面快照 + 解读记录 + 继续追问
└─ Encyclopedia/                     卦象百科（离线只读，起卦页左上角「书」入口）
   ├─ Data/zhouyi.json               内置公有领域周易经文（64卦卦辞 + 384爻辞 + 彖辞）
   ├─ HexagramLore.swift             百科条目模型 + 加载/搜索（EncyclopediaStore）
   ├─ EncyclopediaListView.swift     64 卦网格 + 按卦名/卦辞搜索
   └─ EncyclopediaDetailView.swift   卦辞 / 彖辞 / 六爻辞（初→上）
```

## 历史 / 收藏（M6）

起卦即在本地登记一条卦例（SwiftData），解读产生的对话自动回写同一条（按盘面内容派生的稳定主键去重）。
起卦页左上角「时钟」入口进入历史列表，可按收藏 / 事项类别筛选、滑动删除；详情页可回看盘面与解读、继续追问。
数据仅存本地设备，不上云。

## 解读后端（M4）

解读页需要后端代理在线提供 LLM。先启动后端（默认 mock，无需真实 key）：

```bash
cd ../Backend && pip install -r requirements.txt && uvicorn app.main:app --port 8000
```

客户端默认连 `http://localhost:8000`（模拟器可直连；`project.yml` 已开 `NSAllowsLocalNetworking`）。
真机或线上环境可在 Info.plist 配 `ETIC_BACKEND_BASE_URL` 覆盖。

## 黄金路径

选方法 → 写问题 → 选类别 → 选时间 → 起卦 →（动画）→ 排盘页 → 「请大师解读」→
流式断语 → 输入框追问 → 多轮回复（同一盘面，不重新起卦）。

后端开启 RAG（`ETIC_RAG_ENABLED=true` 并已灌库，见 `../Backend`）时，解读页顶部展示
「经文参考」折叠卡片（本卦卦辞 / 动爻爻辞 / 变卦卦辞原文）；后端未开 RAG 或不可达时
静默留空，不影响解读。
