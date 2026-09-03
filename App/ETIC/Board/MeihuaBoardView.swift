import SwiftUI
import DivinationEngine

/// 梅花易数体用视图（引擎按体用生克算定，UI 仅展示）。
/// 仅 `board.meihua` 非空（梅花起卦）时呈现，与六爻纳甲盘面并存。
struct MeihuaBoardView: View {
    @AppStorage("app.language") private var _language: String = AppLanguage.en.rawValue
    let meihua: MeihuaView

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.Meihua.title)
                    .font(InkTheme.serifTitle(17))
                    .foregroundStyle(InkTheme.ink)
                Spacer()
                Text("\(L10n.Meihua.moving) · \(positionName(meihua.movingPosition))")
                    .font(InkTheme.serifBody(14))
                    .foregroundStyle(InkTheme.inkSoft)
            }

            HStack(spacing: 12) {
                trigramBadge(L10n.Meihua.ti, meihua.ti, emphasized: true)
                trigramBadge(L10n.Meihua.yong, meihua.yong, emphasized: false)
            }

            HStack(spacing: 12) {
                miniTrigram("\(L10n.Meihua.hu)·\(meihua.huName)", meihua.huUpper, meihua.huLower)
                miniPair(L10n.Meihua.bian, meihua.bianName, meihua.bianYong)
            }

            Divider().background(InkTheme.inkSoft.opacity(0.15))

            Text(L10n.Meihua.relations)
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.ink)
            ForEach(meihua.relations, id: \.subject) { rel in
                relationRow(rel)
            }

            Text(meihua.summary)
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func trigramBadge(_ label: String, _ t: MeihuaTrigramView, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(InkTheme.inkSoft)
            HStack(spacing: 6) {
                Text(t.symbol)
                    .font(.system(size: 24))
                    .foregroundStyle(InkTheme.ink)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(t.name) · \(t.nature)")
                        .font(InkTheme.serifBody(15))
                        .foregroundStyle(InkTheme.ink)
                    Text(t.element)
                        .font(.caption)
                        .foregroundStyle(InkTheme.elementColor(t.element))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(emphasized ? InkTheme.cinnabar.opacity(0.08) : InkTheme.paper.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(emphasized ? InkTheme.cinnabar.opacity(0.35) : InkTheme.inkSoft.opacity(0.2), lineWidth: 1)
        )
    }

    private func miniTrigram(_ label: String, _ upper: MeihuaTrigramView, _ lower: MeihuaTrigramView) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(InkTheme.inkSoft)
            Text("\(L10n.Meihua.huUpper)\(upper.name)\(upper.symbol) · \(L10n.Meihua.huLower)\(lower.name)\(lower.symbol)")
                .font(InkTheme.serifBody(13))
                .foregroundStyle(InkTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func miniPair(_ label: String, _ name: String, _ t: MeihuaTrigramView) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(InkTheme.inkSoft)
            Text("\(name) · \(t.name)\(t.symbol)")
                .font(InkTheme.serifBody(13))
                .foregroundStyle(InkTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func relationRow(_ rel: MeihuaRelationView) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(rel.favorable)
                .font(.caption)
                .foregroundStyle(favorableColor(rel.favorable))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(rel.subject) \(rel.trigram)（\(rel.element)）· \(rel.relation)")
                    .font(InkTheme.serifBody(14))
                    .foregroundStyle(InkTheme.ink)
                Text(rel.note)
                    .font(.caption)
                    .foregroundStyle(InkTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func favorableColor(_ f: String) -> Color {
        switch f {
        case "吉": return InkTheme.cinnabar
        case "凶": return InkTheme.azure
        default: return InkTheme.inkSoft
        }
    }

    private func positionName(_ p: Int) -> String {
        let names = ["初", "二", "三", "四", "五", "上"]
        guard (1...6).contains(p) else { return "\(p)" }
        return names[p - 1] + "爻"
    }
}
