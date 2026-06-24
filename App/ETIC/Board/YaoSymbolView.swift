import SwiftUI

/// 单爻爻象：阳爻为整笔 `——`，阴爻为断笔 `— —`。水墨笔触观感。
struct YaoSymbolView: View {
    let isYang: Bool
    /// 动爻标记："老阳" → ○，"老阴" → ×，其余为 nil。
    let movingMark: String?

    private let barWidth: CGFloat = 76
    private let barHeight: CGFloat = 12

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if isYang {
                    bar(width: barWidth)
                } else {
                    HStack(spacing: 12) {
                        bar(width: (barWidth - 12) / 2)
                        bar(width: (barWidth - 12) / 2)
                    }
                }
            }
            .frame(width: barWidth, height: barHeight)

            Text(movingMark ?? " ")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(InkTheme.cinnabar)
                .frame(width: 14)
        }
    }

    private func bar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(InkTheme.ink)
            .frame(width: width, height: barHeight)
    }

    /// 由 `LineView.value` 推动爻标记。
    static func mark(forValue value: String?) -> String? {
        switch value {
        case "老阳": return "○"
        case "老阴": return "×"
        default: return nil
        }
    }
}
