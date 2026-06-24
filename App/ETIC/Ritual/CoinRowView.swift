import SwiftUI

/// 三枚铜钱。`coins` 中 1=背面、0=字面；`tossing` 时翻滚抖动。
struct CoinRowView: View {
    let coins: [Int]
    let tossing: Bool

    var body: some View {
        HStack(spacing: 18) {
            ForEach(0..<3, id: \.self) { i in
                CoinView(isBack: (coins.indices.contains(i) ? coins[i] : 0) == 1, tossing: tossing)
            }
        }
    }
}

private struct CoinView: View {
    let isBack: Bool
    let tossing: Bool

    @State private var flip = false

    private let size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(isBack ? InkTheme.cinnabar.opacity(0.85) : InkTheme.card)
                .overlay(Circle().stroke(InkTheme.ink.opacity(0.7), lineWidth: 2))
            // 古钱方孔
            RoundedRectangle(cornerRadius: 2)
                .fill(InkTheme.paper)
                .frame(width: size * 0.26, height: size * 0.26)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(InkTheme.ink.opacity(0.7), lineWidth: 1.5))
            Text(isBack ? "背" : "字")
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(isBack ? InkTheme.card : InkTheme.ink)
                .offset(y: size * 0.26)
        }
        .frame(width: size, height: size)
        .rotation3DEffect(.degrees(flip ? 360 : 0), axis: (x: 1, y: 0.3, z: 0))
        .animation(tossing ? .linear(duration: 0.18).repeatForever(autoreverses: false) : .default, value: flip)
        .onChange(of: tossing) { active in
            flip = active
        }
        .onAppear { flip = tossing }
    }
}
