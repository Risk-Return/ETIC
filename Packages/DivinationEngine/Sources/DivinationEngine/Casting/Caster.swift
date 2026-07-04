import Foundation

/// 起卦方式。
public enum CastMethod: String, Codable, Sendable {
    case coins = "铜钱"
    case number = "报数"
    case time = "时间"
    case random = "随机"
    case manual = "手动"
}

/// 起卦结果：六爻老少阴阳（自下而上，index 0 = 初爻）。
public struct CastResult: Codable, Hashable, Sendable {
    public let method: CastMethod
    public let lines: [LineValue]

    public init(method: CastMethod, lines: [LineValue]) {
        precondition(lines.count == 6, "需要 6 爻")
        self.method = method
        self.lines = lines
    }

    /// 本卦。
    public var primary: Hexagram {
        Hexagram(lines: lines.map { $0.yinYang })
    }

    /// 动爻位（1...6）。
    public var movingPositions: [Int] {
        lines.enumerated().filter { $0.element.isMoving }.map { $0.offset + 1 }
    }

    /// 变卦（若无动爻则与本卦相同）。
    public var changed: Hexagram {
        Hexagram(lines: lines.map { $0.changedYinYang })
    }
}

/// 起卦器。所有方法均为纯函数，便于复现与测试。
public enum Caster {

    /// 由「铜钱阳面数」起卦。`backs` 为六次摇卦各自的阳面（背）个数（0...3），index 0 = 初爻。
    ///
    /// 约定（《增删卜易》派）：3 背 = 老阳（动）、2 背 = 少阴、1 背 = 少阳、0 背 = 老阴（动）。
    public static func fromCoinBacks(_ backs: [Int]) -> CastResult {
        precondition(backs.count == 6, "需要 6 次摇卦")
        let lines = backs.map { lineValue(forBacks: $0) }
        return CastResult(method: .coins, lines: lines)
    }

    static func lineValue(forBacks backs: Int) -> LineValue {
        switch backs {
        case 3: return .oldYang
        case 2: return .youngYin
        case 1: return .youngYang
        case 0: return .oldYin
        default: preconditionFailure("背数须在 0...3")
        }
    }

    /// 数字起卦（梅花易数）：上卦数、下卦数、动爻数。
    /// 上卦 = upper 先天数取八卦；下卦 = lower；动爻 = (upper+lower) 余 6。
    public static func fromNumbers(upper: Int, lower: Int) -> CastResult {
        let upperTrigram = Trigram.from(innateNumber: upper)
        let lowerTrigram = Trigram.from(innateNumber: lower)
        let movingRaw = (upper + lower) % 6
        let movingPos = movingRaw == 0 ? 6 : movingRaw
        return assemble(lower: lowerTrigram, upper: upperTrigram, movingPosition: movingPos, method: .number)
    }

    /// 时间起卦（梅花，阳历简化版）：以四柱地支序与公历月日参与计算。
    /// 上卦 = (年支序 + 月 + 日) 余 8；下卦 = (年支序 + 月 + 日 + 时支序) 余 8；
    /// 动爻 = (年支序 + 月 + 日 + 时支序) 余 6。其中支序取「子=1…亥=12」。
    public static func fromTime(_ pillars: GanzhiCalendar.FourPillars, month: Int, day: Int) -> CastResult {
        let yearNum = pillars.year.branch.rawValue + 1
        let hourNum = pillars.hour.branch.rawValue + 1
        let upperSum = yearNum + month + day
        let lowerSum = yearNum + month + day + hourNum
        let upperTrigram = Trigram.from(innateNumber: upperSum)
        let lowerTrigram = Trigram.from(innateNumber: lowerSum)
        let movingRaw = lowerSum % 6
        let movingPos = movingRaw == 0 ? 6 : movingRaw
        return assemble(lower: lowerTrigram, upper: upperTrigram, movingPosition: movingPos, method: .time)
    }

    /// 随机起卦：用给定随机源模拟「三枚铜钱摇六次」。
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> CastResult {
        let backs = (0..<6).map { _ in
            (0..<3).reduce(0) { acc, _ in acc + (Bool.random(using: &generator) ? 1 : 0) }
        }
        return CastResult(method: .random, lines: backs.map { lineValue(forBacks: $0) })
    }

    public static func random() -> CastResult {
        var g = SystemRandomNumberGenerator()
        return random(using: &g)
    }

    // MARK: - 由上下卦与动爻位组装六爻

    private static func assemble(lower: Trigram, upper: Trigram, movingPosition: Int, method: CastMethod) -> CastResult {
        let yinYangs = lower.lines + upper.lines // 6, 自下而上
        var values: [LineValue] = yinYangs.map { $0 == .yang ? .youngYang : .youngYin }
        let idx = movingPosition - 1
        switch yinYangs[idx] {
        case .yang: values[idx] = .oldYang
        case .yin: values[idx] = .oldYin
        }
        return CastResult(method: method, lines: values)
    }
}
