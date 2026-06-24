import Foundation
import SwiftUI
import DivinationEngine

@MainActor
final class CastingViewModel: ObservableObject {
    @Published var method: CastMethod = .coins
    @Published var question: String = ""
    @Published var category: QuestionCategory = .general
    @Published var date: Date = Date()
    @Published var upperNumber: String = ""
    @Published var lowerNumber: String = ""

    @Published var board: DivinationBoard?
    @Published var errorMessage: String?

    /// M2 起卦方法范围（手动起卦留到后续）。
    let methods: [CastMethod] = [.coins, .number, .time, .random]

    func cast() {
        errorMessage = nil
        let input = DivinationService.Input(
            method: method,
            question: question,
            category: category,
            date: date,
            upperNumber: Int(upperNumber) ?? 0,
            lowerNumber: Int(lowerNumber) ?? 0,
            coinBacks: randomCoinBacks()
        )
        do {
            board = try DivinationService.makeBoard(input)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 铜钱法：模拟「三枚铜钱摇六次」的背面数（0...3），index 0 = 初爻。
    /// 真正的摇卦交互与动画在 M3 接入 CoreMotion / CoreHaptics。
    private func randomCoinBacks() -> [Int] {
        (0..<6).map { _ in (0..<3).reduce(0) { acc, _ in acc + (Bool.random() ? 1 : 0) } }
    }
}
