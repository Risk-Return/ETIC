import SwiftUI
import DivinationEngine

/// 用神建议（引擎按占问类别给出，UI 仅展示）。
struct UseGodView: View {
    let useGod: UseGodSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("用神")
                    .font(InkTheme.serifTitle(17))
                    .foregroundStyle(InkTheme.ink)
                Spacer()
                Text("\(useGod.category) · \(useGod.relative)")
                    .font(InkTheme.serifBody(15))
                    .foregroundStyle(InkTheme.cinnabar)
            }
            Text(useGod.rationale)
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.inkSoft)
            if useGod.positions.isEmpty {
                Text("本卦未见该用神（伏神，需另寻），可作为解读提示。")
                    .font(.footnote)
                    .foregroundStyle(InkTheme.inkSoft)
            } else {
                Text("用神所在爻位：" + useGod.positions.map(positionName).joined(separator: "、"))
                    .font(.footnote)
                    .foregroundStyle(InkTheme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func positionName(_ p: Int) -> String {
        let names = ["初", "二", "三", "四", "五", "上"]
        guard (1...6).contains(p) else { return "\(p)" }
        return names[p - 1] + "爻"
    }
}
