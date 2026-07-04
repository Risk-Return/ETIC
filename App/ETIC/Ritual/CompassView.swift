import SwiftUI

/// 太极 / 八卦罗盘，缓慢旋转入场。原生 Canvas + TimelineView，无第三方依赖。
struct CompassView: View {
    /// 是否旋转（Reduce Motion 时传 false，保持静止）。
    var rotating: Bool = true

    /// 先天八卦自上顺时针：乾兑离震巽坎艮坤（以三爻 0=阴 1=阳，由上爻→下爻）。
    private let trigrams: [[Int]] = [
        [1, 1, 1], [1, 1, 0], [1, 0, 1], [1, 0, 0],
        [0, 1, 1], [0, 1, 0], [0, 0, 1], [0, 0, 0]
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !rotating)) { timeline in
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 4
                let angle = rotating ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60) / 60 * 2 * .pi : 0

                drawBaguaRing(ctx, center: center, radius: radius, baseAngle: angle)
                drawTaiji(ctx, center: center, radius: radius * 0.52, rotation: -angle * 1.5)
            }
        }
    }

    private func drawBaguaRing(_ ctx: GraphicsContext, center: CGPoint, radius: CGFloat, baseAngle: Double) {
        let ringInner = radius * 0.66
        let ringOuter = radius * 0.98
        var ring = Path()
        ring.addArc(center: center, radius: ringOuter, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
        ring.addArc(center: center, radius: ringInner, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
        ctx.stroke(Path(ellipseIn: CGRect(x: center.x - ringOuter, y: center.y - ringOuter, width: ringOuter * 2, height: ringOuter * 2)),
                   with: .color(InkTheme.ink.opacity(0.25)), lineWidth: 1)

        let lineGap = (ringOuter - ringInner) / 3.2
        for (i, tri) in trigrams.enumerated() {
            let slot = baseAngle + Double(i) / Double(trigrams.count) * 2 * .pi - .pi / 2
            for (row, yang) in tri.enumerated() {
                let r = ringInner + lineGap * (CGFloat(row) + 0.7)
                drawTrigramLine(ctx, center: center, angle: slot, radius: r, isYang: yang == 1, span: 0.32)
            }
        }
    }

    private func drawTrigramLine(_ ctx: GraphicsContext, center: CGPoint, angle: Double, radius: CGFloat, isYang: Bool, span: Double) {
        func point(_ a: Double) -> CGPoint {
            let ra = CGFloat(a)
            return CGPoint(x: center.x + cos(ra) * radius, y: center.y + sin(ra) * radius)
        }
        let color = GraphicsContext.Shading.color(InkTheme.ink.opacity(0.6))
        if isYang {
            var p = Path()
            p.move(to: point(angle - span / 2))
            p.addLine(to: point(angle + span / 2))
            ctx.stroke(p, with: color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        } else {
            var p1 = Path(); p1.move(to: point(angle - span / 2)); p1.addLine(to: point(angle - span * 0.1))
            var p2 = Path(); p2.move(to: point(angle + span * 0.1)); p2.addLine(to: point(angle + span / 2))
            ctx.stroke(p1, with: color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            ctx.stroke(p2, with: color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }

    private func drawTaiji(_ ctx: GraphicsContext, center: CGPoint, radius: CGFloat, rotation: Double) {
        var inner = ctx
        inner.translateBy(x: center.x, y: center.y)
        inner.rotate(by: .radians(rotation))

        let r = radius
        // 黑白两仪
        var yin = Path()
        yin.addArc(center: .zero, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        yin.addArc(center: CGPoint(x: 0, y: r / 2), radius: r / 2, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
        yin.addArc(center: CGPoint(x: 0, y: -r / 2), radius: r / 2, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: false)
        inner.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(InkTheme.paper))
        inner.fill(yin, with: .color(InkTheme.ink))
        inner.stroke(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(InkTheme.ink), lineWidth: 1.5)

        let eye = r * 0.16
        inner.fill(Path(ellipseIn: CGRect(x: -eye, y: -r / 2 - eye, width: eye * 2, height: eye * 2)), with: .color(InkTheme.paper))
        inner.fill(Path(ellipseIn: CGRect(x: -eye, y: r / 2 - eye, width: eye * 2, height: eye * 2)), with: .color(InkTheme.ink))
    }
}
