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

    /// 真太阳时校正所用经度（东正西负）。nil = 不校正，直接用设备时区民用时。
    @Published var longitude: Double?
    /// 经度来源的展示名（城市名或「Custom」）。
    @Published var locationName: String?

    @Published var board: DivinationBoard?
    @Published var errorMessage: String?

    func selectCity(_ city: WorldCity) {
        longitude = city.longitude
        locationName = "\(city.name), \(city.region)"
    }

    func setCustomLongitude(_ value: Double) {
        longitude = value
        locationName = nil
    }

    func clearLocation() {
        longitude = nil
        locationName = nil
    }

    /// 起卦方法范围（手动起卦留到后续）。梅花易数以「报数」呈现为独立方法。
    let methods: [CastMethod] = [.coins, .meihua, .time, .random]

    func cast() {
        errorMessage = nil
        let input = DivinationService.Input(
            method: method,
            question: question,
            category: category,
            date: date,
            upperNumber: Int(upperNumber) ?? 0,
            lowerNumber: Int(lowerNumber) ?? 0,
            coinBacks: randomCoinBacks(),
            longitude: longitude
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
