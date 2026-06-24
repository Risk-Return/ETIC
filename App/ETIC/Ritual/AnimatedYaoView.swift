import SwiftUI

/// 成卦时单爻的"水墨笔触写出"：阳爻整笔、阴爻断笔，沿笔画方向 trim 揭示。
struct AnimatedYaoView: View {
    let isYang: Bool
    /// 是否已揭示（true 时从左到右写出，false 时不显示）。
    let revealed: Bool
    /// Reduce Motion：直接淡入，不做笔触 trim。
    var reduceMotion: Bool = false

    private let width: CGFloat = 150
    private let height: CGFloat = 16

    var body: some View {
        Group {
            if reduceMotion {
                YaoStroke(isYang: isYang)
                    .stroke(InkTheme.ink, style: StrokeStyle(lineWidth: height, lineCap: .round))
                    .opacity(revealed ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: revealed)
            } else {
                YaoStroke(isYang: isYang)
                    .trim(from: 0, to: revealed ? 1 : 0)
                    .stroke(InkTheme.ink, style: StrokeStyle(lineWidth: height, lineCap: .round))
                    .animation(.easeInOut(duration: 0.55), value: revealed)
            }
        }
        .frame(width: width, height: height)
    }
}

/// 爻的笔画路径。阳爻一条整笔；阴爻两段（中间断开）。
private struct YaoStroke: Shape {
    let isYang: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.midY
        let inset = rect.height / 2
        if isYang {
            p.move(to: CGPoint(x: rect.minX + inset, y: y))
            p.addLine(to: CGPoint(x: rect.maxX - inset, y: y))
        } else {
            let gap = rect.width * 0.18
            let segEnd = rect.midX - gap / 2
            let segStart = rect.midX + gap / 2
            p.move(to: CGPoint(x: rect.minX + inset, y: y))
            p.addLine(to: CGPoint(x: segEnd, y: y))
            p.move(to: CGPoint(x: segStart, y: y))
            p.addLine(to: CGPoint(x: rect.maxX - inset, y: y))
        }
        return p
    }
}
