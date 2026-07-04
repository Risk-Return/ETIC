import SwiftUI
import DivinationEngine

/// 盘面单行：六神 · 六亲 · 干支 · 爻象 · 世应/旬空 · 旺衰。
struct BoardRowView: View {
    let line: LineView
    /// 六神按爻位与日干而定，本卦/变卦同位一致；变卦行复用本卦六神。
    let sixGod: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(sixGod ?? "")
                .font(InkTheme.serifBody(13))
                .foregroundStyle(InkTheme.inkSoft)
                .frame(width: 30, alignment: .leading)

            Text(line.sixRelative)
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.ink)
                .frame(width: 28, alignment: .leading)

            HStack(spacing: 2) {
                Text(line.stem + line.branch)
                    .font(InkTheme.serifBody(15))
                    .foregroundStyle(InkTheme.ink)
                Text(line.element)
                    .font(.caption2)
                    .foregroundStyle(InkTheme.elementColor(line.element))
            }
            .frame(width: 56, alignment: .leading)

            YaoSymbolView(
                isYang: line.yinYang == "阳",
                movingMark: YaoSymbolView.mark(forValue: line.value)
            )

            Spacer(minLength: 4)

            markers

            Text(line.strength)
                .font(.caption2)
                .foregroundStyle(InkTheme.inkSoft)
                .frame(width: 18)
        }
        .padding(.vertical, 6)
        .opacity(line.isVoid ? 0.55 : 1)
    }

    private var markers: some View {
        HStack(spacing: 4) {
            if line.isWorld { badge(L10n.Board.world, InkTheme.cinnabar) }
            if line.isResponse { badge(L10n.Board.response, InkTheme.azure) }
            if line.isVoid { badge(L10n.Board.void, InkTheme.inkSoft) }
        }
        .frame(width: 64, alignment: .trailing)
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(color, lineWidth: 1))
    }
}
