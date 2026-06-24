import Foundation

/// 五行（Wu Xing / Five Phases）。
public enum WuXing: String, Codable, CaseIterable, Sendable {
    case wood = "木"
    case fire = "火"
    case earth = "土"
    case metal = "金"
    case water = "水"

    /// 我所生（生），如木生火。
    public var generates: WuXing {
        switch self {
        case .wood: return .fire
        case .fire: return .earth
        case .earth: return .metal
        case .metal: return .water
        case .water: return .wood
        }
    }

    /// 我所克（克），如木克土。
    public var controls: WuXing {
        switch self {
        case .wood: return .earth
        case .earth: return .water
        case .water: return .fire
        case .fire: return .metal
        case .metal: return .wood
        }
    }

    /// 生我者（印）。
    public var generatedBy: WuXing {
        WuXing.allCases.first { $0.generates == self }!
    }

    /// 克我者（官）。
    public var controlledBy: WuXing {
        WuXing.allCases.first { $0.controls == self }!
    }

    /// 两个五行之间的关系（以 self 为「我」的视角）。
    public enum Relation: String, Codable, Sendable {
        case same = "比和"
        case iGenerate = "我生"
        case generatesMe = "生我"
        case iControl = "我克"
        case controlsMe = "克我"
    }

    public func relation(to other: WuXing) -> Relation {
        if self == other { return .same }
        if generates == other { return .iGenerate }
        if generatedBy == other { return .generatesMe }
        if controls == other { return .iControl }
        return .controlsMe
    }
}
