import SwiftUI
import DivinationEngine

/// 占卜动画编排：引擎已把盘面算好，这里只按结果"演出"摇卦→成卦→变卦→盘面。
/// 任何阶段都可「跳过」直达盘面；Reduce Motion 时直接跳过。
@MainActor
final class RitualViewModel: ObservableObject {
    enum Stage: Int { case prepare, shaking, transforming, board }

    let board: DivinationBoard
    /// 合并「系统 Reduce Motion」与「用户跳过开关」，在 onAppear 时由环境注入。
    private(set) var reduceMotion: Bool = false

    @Published private(set) var stage: Stage = .prepare
    /// 已摇出的爻数（0...6），逐爻自下而上揭示（对应初→上）。
    @Published private(set) var revealed: Int = 0
    /// 三枚铜钱当前展示的背数（0/1）。
    @Published private(set) var coins: [Int] = [0, 0, 0]
    @Published private(set) var isTossing: Bool = false
    /// 变卦阶段：动爻高亮闪烁。
    @Published var flashMoving: Bool = false

    let haptics = HapticsEngine()
    private var tossing = false

    /// 每爻铜钱目标背数（index 0 = 初爻），由本卦各爻老少阴阳反推（与引擎约定一致）。
    private let targetBacks: [Int]

    var totalThrows: Int { 6 }
    var hasChanged: Bool { board.changed != nil }
    var allThrown: Bool { revealed >= totalThrows }

    init(board: DivinationBoard) {
        self.board = board
        self.targetBacks = board.primary.lines
            .sorted { $0.position < $1.position }
            .map { Self.backs(forValue: $0.value) }
    }

    /// 由爻值反推铜钱背数：老阳=3、少阴=2、少阳=1、老阴=0（《增删卜易》派，与 Caster 一致）。
    static func backs(forValue value: String?) -> Int {
        switch value {
        case "老阳": return 3
        case "少阴": return 2
        case "少阳": return 1
        case "老阴": return 0
        default: return 2
        }
    }

    func onAppear(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        if reduceMotion {
            stage = .board
            revealed = totalThrows
            return
        }
        haptics.prepare()
    }

    func onDisappear() {
        haptics.stop()
    }

    func beginShaking() {
        guard stage == .prepare else { return }
        withAnimation(.easeInOut(duration: 0.4)) { stage = .shaking }
    }

    /// 一次摇卦：摇一摇或点击触发。结果已定，仅演出当前爻的铜钱与笔画。
    func toss() {
        guard stage == .shaking, !tossing, !allThrown else { return }
        tossing = true
        isTossing = true

        Task {
            // 翻滚 ~0.7s：随机抖动铜钱面。
            let frames = 7
            for _ in 0..<frames {
                coins = (0..<3).map { _ in Int.random(in: 0...1) }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            // 落定为目标背数。
            let backs = targetBacks[revealed]
            coins = Self.coinFaces(backs: backs)
            isTossing = false
            haptics.coinDrop()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                revealed += 1
            }
            tossing = false

            if allThrown {
                try? await Task.sleep(nanoseconds: 600_000_000)
                finishShaking()
            }
        }
    }

    private func finishShaking() {
        if hasChanged {
            withAnimation(.easeInOut(duration: 0.4)) { stage = .transforming }
            Task {
                // 动爻闪烁三次。
                for _ in 0..<3 {
                    withAnimation(.easeInOut(duration: 0.25)) { flashMoving = true }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    withAnimation(.easeInOut(duration: 0.25)) { flashMoving = false }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    haptics.tap()
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
                revealBoard()
            }
        } else {
            Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                revealBoard()
            }
        }
    }

    private func revealBoard() {
        withAnimation(.easeInOut(duration: 0.5)) { stage = .board }
    }

    /// 跳过动画，直达盘面。
    func skip() {
        revealed = totalThrows
        withAnimation(.easeInOut(duration: 0.3)) { stage = .board }
    }

    /// 把背数映射为三枚铜钱的「背面(1)/字面(0)」展示。
    static func coinFaces(backs: Int) -> [Int] {
        let b = max(0, min(3, backs))
        return (0..<3).map { $0 < b ? 1 : 0 }
    }
}
