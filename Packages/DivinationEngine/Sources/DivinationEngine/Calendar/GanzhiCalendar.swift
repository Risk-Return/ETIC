import Foundation

/// 公历（阳历）→ 干支历换算。支持 1900...2100（节气表覆盖范围）。
///
/// 规则：
/// - 年柱以「立春」换岁；
/// - 月柱以「节」（立春、惊蛰…大雪）为各月分界，月干用五虎遁；
/// - 日柱用儒略日序推算（dayIndex = (JDN + 49) % 60）；
/// - 时柱以两小时为一支（子时 23:00–01:00），时干用五鼠遁。
public enum GanzhiCalendar {

    public struct FourPillars: Codable, Hashable, Sendable {
        public let year: Ganzhi
        public let month: Ganzhi
        public let day: Ganzhi
        public let hour: Ganzhi
    }

    public enum CalendarError: Error, Sendable {
        case yearOutOfRange(Int)
    }

    /// 儒略日序（正午，整数）。
    public static func julianDayNumber(year: Int, month: Int, day: Int) -> Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    /// 日柱干支序号（0 = 甲子）。
    public static func dayIndex(year: Int, month: Int, day: Int) -> Int {
        let jdn = julianDayNumber(year: year, month: month, day: day)
        return ((jdn + 49) % 60 + 60) % 60
    }

    /// 完整四柱换算。`hour` 为 0...23（24 小时制）。
    public static func fourPillars(year: Int, month: Int, day: Int, hour: Int) throws -> FourPillars {
        guard year >= SolarTermTable.firstYear, year <= SolarTermTable.lastYear else {
            throw CalendarError.yearOutOfRange(year)
        }
        let nodes = SolarTermTable.nodeDays[year - SolarTermTable.firstYear]
        let lichunDay = nodes[1] // 2 月立春

        // 年柱（立春换岁）
        let beforeLichun = month < 2 || (month == 2 && day < lichunDay)
        let effectiveYear = beforeLichun ? year - 1 : year
        let yearIdx = ((effectiveYear - 1984) % 60 + 60) % 60
        let yearGZ = Ganzhi(index: yearIdx)

        // 月柱
        let nodeDay = nodes[month - 1]
        let afterNode = day >= nodeDay
        let monthBranchIdx = afterNode ? (month % 12) : ((month - 1) % 12)
        let monthBranch = Branch(rawValue: monthBranchIdx)!
        // 五虎遁：寅月天干由年干推
        let yearStem = yearGZ.stem.rawValue
        let yinMonthStem = ((yearStem % 5) * 2 + 2) % 10
        let offsetFromYin = ((monthBranchIdx - Branch.yin.rawValue) % 12 + 12) % 12
        let monthStemIdx = (yinMonthStem + offsetFromYin) % 10
        let monthGZ = Ganzhi(stem: Stem(rawValue: monthStemIdx)!, branch: monthBranch)

        // 日柱
        let dayGZ = Ganzhi(index: dayIndex(year: year, month: month, day: day))

        // 时柱：23:00 起为子时，按「晚子时」归次日推时干（日柱不变）
        let hourBranchIdx = ((hour + 1) / 2) % 12
        let hourBranch = Branch(rawValue: hourBranchIdx)!
        let dayStemForHour = hour == 23
            ? Ganzhi(index: dayIndex(year: year, month: month, day: day) + 1).stem
            : dayGZ.stem
        let ziHourStem = (dayStemForHour.rawValue % 5) * 2 % 10
        let hourStemIdx = (ziHourStem + hourBranchIdx) % 10
        let hourGZ = Ganzhi(stem: Stem(rawValue: hourStemIdx)!, branch: hourBranch)

        return FourPillars(year: yearGZ, month: monthGZ, day: dayGZ, hour: hourGZ)
    }

    /// 便捷：以 `Date` 与时区换算四柱。
    public static func fourPillars(date: Date, timeZone: TimeZone = TimeZone(identifier: "Asia/Shanghai")!) throws -> FourPillars {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day, .hour], from: date)
        return try fourPillars(year: c.year!, month: c.month!, day: c.day!, hour: c.hour!)
    }
}
