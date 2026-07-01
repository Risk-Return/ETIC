import SwiftUI

/// 卦象百科详情：卦名 + 卦辞 + 彖辞 + 六爻辞（初→上）。经文只读展示。
struct EncyclopediaDetailView: View {
    let lore: HexagramLore

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    section("卦辞", text: lore.judgment)
                    if let tuan = lore.tuan, !tuan.isEmpty {
                        section("彖辞", text: tuan)
                    }
                    linesSection
                    disclaimer
                }
                .padding(20)
            }
        }
        .navigationTitle(lore.short)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lore.name)
                .font(InkTheme.serifTitle(28))
                .foregroundStyle(InkTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(InkTheme.serifTitle(17))
                .foregroundStyle(InkTheme.cinnabar)
            Text(text)
                .font(InkTheme.serifBody(16))
                .foregroundStyle(InkTheme.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private var linesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("爻辞")
                .font(InkTheme.serifTitle(17))
                .foregroundStyle(InkTheme.cinnabar)
            ForEach(lore.orderedLines, id: \.position) { line in
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.positionLabel(line.position))
                        .font(.caption)
                        .foregroundStyle(InkTheme.inkSoft)
                    Text(line.text)
                        .font(InkTheme.serifBody(16))
                        .foregroundStyle(InkTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if line.position != 6 {
                    Divider().background(InkTheme.inkSoft.opacity(0.15))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private static func positionLabel(_ position: Int) -> String {
        let names = ["初", "二", "三", "四", "五", "上"]
        guard (1...6).contains(position) else { return "\(position)爻" }
        return "第\(names[position - 1])爻"
    }

    private var disclaimer: some View {
        Text("经文为公有领域《周易》原文，仅供查阅参考。")
            .font(.caption2)
            .foregroundStyle(InkTheme.inkSoft)
    }
}

#Preview {
    NavigationStack {
        EncyclopediaDetailView(lore: EncyclopediaStore.all.first ?? HexagramLore(
            name: "乾为天", short: "乾", judgment: "元，亨，利，贞。",
            lines: ["1": "初九：潜龙，勿用。"], tuan: nil))
    }
}
