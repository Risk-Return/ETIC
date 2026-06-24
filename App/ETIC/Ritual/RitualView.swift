import SwiftUI
import DivinationEngine

/// 占卜动画容器：罗盘入场 → 摇卦 → 成卦 → 动爻变卦 → 盘面。引擎已算好，仅"演出"。
struct RitualView: View {
    let board: DivinationBoard

    @StateObject private var model: RitualViewModel
    @StateObject private var shake = ShakeDetector()
    @EnvironmentObject private var settings: RitualSettings
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    init(board: DivinationBoard) {
        self.board = board
        _model = StateObject(wrappedValue: RitualViewModel(board: board))
    }

    private var lines: [LineView] {
        board.primary.lines.sorted { $0.position < $1.position }
    }

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()

            switch model.stage {
            case .prepare:
                prepareStage
            case .shaking:
                shakingStage
            case .transforming:
                formingStage(transforming: true)
            case .board:
                BoardView(board: board, animateReveal: !model.reduceMotion)
                    .transition(.opacity)
            }

            if model.stage != .board {
                skipButton
            }
        }
        .navigationTitle(model.stage == .board ? "排盘" : "起卦")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.onAppear(reduceMotion: systemReduceMotion || settings.skipAnimation)
            if settings.shakeToToss {
                shake.onShake = { if model.stage == .shaking { model.toss() } }
                shake.start()
            }
        }
        .onDisappear {
            shake.stop()
            model.onDisappear()
        }
    }

    // MARK: 阶段视图

    private var prepareStage: some View {
        VStack(spacing: 28) {
            Spacer()
            CompassView(rotating: true)
                .frame(width: 240, height: 240)
            Text("静心默念所问之事")
                .font(InkTheme.serifTitle(20))
                .foregroundStyle(InkTheme.ink)
            if let q = board.question, !q.isEmpty {
                Text(q).font(InkTheme.serifBody(15)).foregroundStyle(InkTheme.inkSoft)
            }
            Spacer()
            Button(action: model.beginShaking) {
                Text("开始摇卦")
                    .font(InkTheme.serifTitle(18))
                    .foregroundStyle(InkTheme.card)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(InkTheme.ink, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    private var shakingStage: some View {
        VStack(spacing: 24) {
            Spacer()
            CoinRowView(coins: model.coins, tossing: model.isTossing)
            Text(shakePrompt)
                .font(InkTheme.serifBody(15))
                .foregroundStyle(InkTheme.inkSoft)
            formingStack
            Spacer()
            Button(action: model.toss) {
                Text(model.allThrown ? "成卦中…" : "摇卦（\(model.revealed)/6）")
                    .font(InkTheme.serifTitle(18))
                    .foregroundStyle(InkTheme.card)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(model.allThrown ? InkTheme.inkSoft : InkTheme.cinnabar,
                                in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(model.isTossing || model.allThrown)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    private func formingStage(transforming: Bool) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Text("动爻变卦")
                .font(InkTheme.serifTitle(20))
                .foregroundStyle(InkTheme.cinnabar)
            formingStack
            Spacer().frame(height: 80)
            Spacer()
        }
    }

    private var formingStack: some View {
        VStack(spacing: 16) {
            // 自上而下渲染：上爻在顶。
            ForEach(lines.reversed(), id: \.position) { line in
                HStack(spacing: 12) {
                    AnimatedYaoView(
                        isYang: line.yinYang == "阳",
                        revealed: line.position <= model.revealed,
                        reduceMotion: model.reduceMotion
                    )
                    Text(movingMark(line) ?? " ")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(InkTheme.cinnabar)
                        .frame(width: 16)
                        .opacity(line.moving ? (model.stage == .transforming ? (model.flashMoving ? 1 : 0.25) : 1) : 0)
                }
            }
        }
    }

    private var skipButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: model.skip) {
                    Text("跳过动画")
                        .font(.footnote)
                        .foregroundStyle(InkTheme.inkSoft)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(Capsule().stroke(InkTheme.inkSoft.opacity(0.4), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
    }

    private var shakePrompt: String {
        if model.allThrown { return "六爻已成" }
        if shake.isAvailable && settings.shakeToToss { return "摇一摇手机，或点下方按钮摇卦" }
        return "点下方按钮摇卦"
    }

    private func movingMark(_ line: LineView) -> String? {
        switch line.value {
        case "老阳": return "○"
        case "老阴": return "×"
        default: return nil
        }
    }
}
