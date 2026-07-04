import Foundation

/// 占问类别（用于取用神建议）。
public enum QuestionCategory: String, Codable, CaseIterable, Sendable {
    case career = "事业"
    case wealth = "财运"
    case marriage = "婚恋"
    case health = "疾病"
    case study = "考学"
    case lawsuit = "官讼"
    case travel = "出行"
    case lost = "失物"
    case general = "综合"

    public var displayName: String {
        switch self {
        case .career: return String(localized: "category.career")
        case .wealth: return String(localized: "category.wealth")
        case .marriage: return String(localized: "category.marriage")
        case .health: return String(localized: "category.health")
        case .study: return String(localized: "category.study")
        case .lawsuit: return String(localized: "category.lawsuit")
        case .travel: return String(localized: "category.travel")
        case .lost: return String(localized: "category.lost")
        case .general: return String(localized: "category.general")
        }
    }
}

/// 起卦时间信息。
public struct CastTimeInfo: Codable, Hashable, Sendable {
    public let gregorian: String
    public let yearPillar: String
    public let monthPillar: String
    public let dayPillar: String
    public let hourPillar: String
    /// 日空亡（旬空）地支。
    public let voidBranches: [String]
}

/// 单爻在盘面上的呈现。
public struct LineView: Codable, Hashable, Sendable {
    public let position: Int          // 1...6（初→上）
    public let yinYang: String
    public let value: String?         // 老阳/少阳/少阴/老阴（仅本卦）
    public let moving: Bool
    public let stem: String
    public let branch: String
    public let element: String
    public let sixRelative: String
    public let sixGod: String?        // 仅本卦
    public let isWorld: Bool
    public let isResponse: Bool
    public let isVoid: Bool           // 旬空
    public let strength: String       // 旺相休囚死
}

/// 一卦在盘面上的呈现（本卦或变卦）。
public struct HexagramView: Codable, Hashable, Sendable {
    public let name: String
    public let code: Int
    public let upperTrigram: String
    public let lowerTrigram: String
    public let palace: String
    public let palaceElement: String
    public let worldPosition: Int
    public let responsePosition: Int
    public let lines: [LineView]      // 6，初→上
}

/// 用神建议。
public struct UseGodSuggestion: Codable, Hashable, Sendable {
    public let category: String
    public let relative: String       // 建议用神六亲
    public let rationale: String
    /// 本卦中该六亲所在爻位（可能多于一处或无）。
    public let positions: [Int]
}

/// 完整盘面 —— 排盘引擎与 UI / LLM 之间的唯一数据契约。
public struct DivinationBoard: Codable, Hashable, Sendable {
    public static let schemaVersion = "1.0.0"

    public let version: String
    public let method: String
    public let question: String?
    public let category: String?
    public let castTime: CastTimeInfo
    public let movingPositions: [Int]
    public let primary: HexagramView
    public let changed: HexagramView?
    public let useGod: UseGodSuggestion?

    /// 序列化为契约 JSON（键稳定、便于喂给 LLM）。
    public func jsonData(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted
            ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            : [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}
