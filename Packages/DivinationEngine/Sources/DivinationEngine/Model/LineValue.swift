import Foundation

/// 单爻的老少阴阳。
public enum LineValue: String, Codable, CaseIterable, Sendable {
    case oldYang = "老阳"    // ▭ 动，变阴
    case youngYang = "少阳"  // ▭ 静
    case youngYin = "少阴"   // ▬▬ 静
    case oldYin = "老阴"     // ▬▬ 动，变阳

    /// 本爻阴阳。
    public var yinYang: YinYang {
        switch self {
        case .oldYang, .youngYang: return .yang
        case .oldYin, .youngYin: return .yin
        }
    }

    /// 是否为动爻。
    public var isMoving: Bool {
        self == .oldYang || self == .oldYin
    }

    /// 变爻后的阴阳（静爻不变）。
    public var changedYinYang: YinYang {
        isMoving ? yinYang.opposite : yinYang
    }

    /// 排盘符号：老阳 □、少阳 ▭、少阴 ⚏、老阴 ×（仅用于调试展示）。
    public var marker: String {
        switch self {
        case .oldYang: return "○"   // 重，动
        case .youngYang: return "—"
        case .youngYin: return "--"
        case .oldYin: return "×"    // 交，动
        }
    }
}
