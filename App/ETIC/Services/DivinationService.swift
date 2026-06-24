import Foundation
import DivinationEngine

/// 起卦输入 → 调用确定性引擎 → 产出盘面 JSON 契约。
///
/// 这一层是 UI 与引擎之间唯一的桥：UI 只负责收集「方法 / 问题 / 类别 / 起卦参数」，
/// 计算全部交给 `DivinationEngine`，结果即 `DivinationBoard`。本层**不做任何术数计算**。
enum DivinationService {

    enum ServiceError: LocalizedError {
        case invalidNumbers
        case calendarOutOfRange

        var errorDescription: String? {
            switch self {
            case .invalidNumbers: return "报数需为正整数。"
            case .calendarOutOfRange: return "日期超出支持范围（1900–2100）。"
            }
        }
    }

    /// 起卦参数（UI 收集）。
    struct Input {
        var method: CastMethod
        var question: String
        var category: QuestionCategory
        var date: Date
        /// 报数法：上数 / 下数。
        var upperNumber: Int
        var lowerNumber: Int
        /// 手动 / 铜钱：六次摇卦的「背数」(0...3)，index 0 = 初爻。
        var coinBacks: [Int]
    }

    static func makeBoard(_ input: Input, timeZone: TimeZone = .current) throws -> DivinationBoard {
        let pillars: GanzhiCalendar.FourPillars
        do {
            pillars = try GanzhiCalendar.fourPillars(date: input.date, timeZone: timeZone)
        } catch {
            throw ServiceError.calendarOutOfRange
        }

        let comps = calendarComponents(input.date, timeZone: timeZone)
        let cast: CastResult
        switch input.method {
        case .coins, .manual:
            cast = Caster.fromCoinBacks(input.coinBacks)
        case .number:
            guard input.upperNumber > 0, input.lowerNumber > 0 else { throw ServiceError.invalidNumbers }
            cast = Caster.fromNumbers(upper: input.upperNumber, lower: input.lowerNumber)
        case .time:
            cast = Caster.fromTime(pillars, month: comps.month, day: comps.day)
        case .random:
            cast = Caster.random()
        }

        let trimmedQuestion = input.question.trimmingCharacters(in: .whitespacesAndNewlines)
        return LiuyaoEngine.cast(
            cast,
            pillars: pillars,
            gregorianDescription: gregorianDescription(input.date, timeZone: timeZone),
            question: trimmedQuestion.isEmpty ? nil : trimmedQuestion,
            category: input.category
        )
    }

    private static func calendarComponents(_ date: Date, timeZone: TimeZone) -> (month: Int, day: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.month, .day], from: date)
        return (c.month ?? 1, c.day ?? 1)
    }

    private static func gregorianDescription(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }
}
