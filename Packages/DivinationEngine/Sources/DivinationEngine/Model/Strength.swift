import Foundation

/// 旺相休囚死（以月令为参照）。
public enum Strength: String, Codable, CaseIterable, Sendable {
    case prosperous = "旺"  // 同我（当令）
    case strong = "相"      // 月生我
    case resting = "休"     // 我生月
    case trapped = "囚"     // 我克月
    case dead = "死"        // 月克我

    /// monthElement 为月令五行，element 为爻五行。
    public static func of(element: WuXing, monthElement: WuXing) -> Strength {
        switch element.relation(to: monthElement) {
        case .same: return .prosperous
        case .generatesMe: return .strong
        case .iGenerate: return .resting
        case .iControl: return .trapped
        case .controlsMe: return .dead
        }
    }
}
