import Foundation

/// 六亲。以卦宫五行为「我」，按与各爻五行的生克关系确定。
public enum SixRelative: String, Codable, CaseIterable, Sendable {
    case sibling = "兄弟"   // 同我者
    case offspring = "子孙" // 我生者
    case wealth = "妻财"    // 我克者
    case officer = "官鬼"   // 克我者
    case parent = "父母"    // 生我者

    /// selfElement 为卦宫五行（「我」），lineElement 为爻五行。
    public static func of(lineElement: WuXing, selfElement: WuXing) -> SixRelative {
        switch selfElement.relation(to: lineElement) {
        case .same: return .sibling
        case .iGenerate: return .offspring
        case .iControl: return .wealth
        case .controlsMe: return .officer
        case .generatesMe: return .parent
        }
    }
}
