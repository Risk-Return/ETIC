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

// MARK: - 梅花易数（体用生克）

/// 梅花易数视图中的一个三爻卦（体/用/互/变）。
public struct MeihuaTrigramView: Codable, Hashable, Sendable {
    public let name: String        // 乾/兑/离…
    public let symbol: String      // ☰☱☲…
    public let nature: String      // 天/泽/火…
    public let element: String     // 金/木/水/火/土
    /// 该卦在本卦中所处的半（上卦 / 下卦）。互卦、变卦沿用其对应半。
    public let position: String
}

/// 体卦与「用 / 互 / 变」某一卦之间的五行生克关系（均以体卦为「我」）。
public struct MeihuaRelationView: Codable, Hashable, Sendable {
    public let subject: String     // 用卦 / 体互 / 用互 / 变卦
    public let trigram: String     // 该卦名
    public let element: String     // 该卦五行
    public let relation: String    // 生体 / 比和 / 克体 / 体生（泄） / 体克（耗）
    public let favorable: String   // 吉 / 平 / 凶（对体卦而言的倾向，仅供参考）
    public let note: String
}

/// 梅花易数排盘视图：体用分卦、互卦、变卦与体用五行生克。
///
/// 与六爻纳甲口径互补：`DivinationBoard` 在 `method == "梅花"` 时附带此视图，
/// 六爻字段（纳甲/六亲/六神/世应/旬空）仍照常产出，仅解读口径不同。
public struct MeihuaView: Codable, Hashable, Sendable {
    public let movingPosition: Int          // 动爻位（1...6），梅花恒为单一动爻
    public let ti: MeihuaTrigramView        // 体卦（不动之卦，代表求测者自身）
    public let yong: MeihuaTrigramView      // 用卦（含动爻之卦，代表所占之事）
    public let huLower: MeihuaTrigramView   // 下互（2-3-4 爻）
    public let huUpper: MeihuaTrigramView   // 上互（3-4-5 爻）
    public let huName: String               // 互卦名（上互为上、下互为下）
    public let bianName: String             // 变卦名（动爻变后的本卦）
    public let bianYong: MeihuaTrigramView  // 变卦中用卦所变之卦（代表事之结果）
    public let relations: [MeihuaRelationView] // 用/体互/用互/变 对体卦的生克
    public let summary: String              // 综合体用生克的吉凶倾向（中性、非绝对）
}

/// 完整盘面 —— 排盘引擎与 UI / LLM 之间的唯一数据契约。
public struct DivinationBoard: Codable, Hashable, Sendable {
    /// v1.1.0：新增**可选** `meihua` 视图（仅梅花起卦时非空），六爻字段不变，向后兼容。
    public static let schemaVersion = "1.1.0"

    public let version: String
    public let method: String
    public let question: String?
    public let category: String?
    public let castTime: CastTimeInfo
    public let movingPositions: [Int]
    public let primary: HexagramView
    public let changed: HexagramView?
    public let useGod: UseGodSuggestion?
    /// 梅花易数体用生克视图。仅 `method == "梅花"` 时非空；其余起卦法为 `nil`。
    public let meihua: MeihuaView?

    /// 序列化为契约 JSON（键稳定、便于喂给 LLM）。
    public func jsonData(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted
            ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            : [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}
