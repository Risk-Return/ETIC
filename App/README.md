# ETIC iOS App（M2：起卦 + 静态排盘）

SwiftUI 客户端。消费 `DivinationEngine` 冻结的 `DivinationBoard` 契约渲染盘面。
本阶段仅静态渲染：**无动画（M3）**、**无 LLM 解读（M4，仅留入口）**。

## 本地构建（需 macOS + Xcode 15+）

工程用 [XcodeGen](https://github.com/yonyz/XcodeGen) 管理，`.xcodeproj` 不入库。

```bash
brew install xcodegen          # 若未安装
cd App
xcodegen generate              # 由 project.yml 生成 ETIC.xcodeproj
open ETIC.xcodeproj            # 选 iOS 16+ 模拟器运行
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
└─ Board/
   ├─ BoardView.swift          排盘页：标题、本卦/变卦切换、盘面表、四柱、用神、解读入口
   ├─ BoardRowView.swift       单行：六神·六亲·干支·爻象·世应/旬空·旺衰
   ├─ YaoSymbolView.swift      爻象笔画（阳整笔/阴断笔 + ○× 动爻标记）
   ├─ FourPillarsView.swift    年月日时四柱 + 旬空
   ├─ UseGodView.swift         用神建议
   └─ PreviewData.swift        SwiftUI 预览用确定性样例盘
```

## 黄金路径

选方法 → 写问题 → 选类别 → 选时间 → 起卦 → 进入排盘页查看完整盘面（含动爻时可切换本卦/变卦）。
