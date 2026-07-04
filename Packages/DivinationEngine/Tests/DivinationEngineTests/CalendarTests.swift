import XCTest
@testable import DivinationEngine

/// 干支历换算测试。期望值由天文历算库 sxtwl 预生成（见 docs / 生成脚本）。
final class CalendarTests: XCTestCase {

    private struct Fixture {
        let y, m, d, h: Int
        let year, month, day, hour: String
    }

    private let fixtures: [Fixture] = [
        Fixture(y: 2024, m: 2, d: 4, h: 12, year: "甲辰", month: "丙寅", day: "戊戌", hour: "戊午"),
        Fixture(y: 2024, m: 2, d: 3, h: 12, year: "癸卯", month: "乙丑", day: "丁酉", hour: "丙午"),
        Fixture(y: 2024, m: 2, d: 5, h: 0, year: "甲辰", month: "丙寅", day: "己亥", hour: "甲子"),
        Fixture(y: 2025, m: 12, d: 21, h: 23, year: "乙巳", month: "戊子", day: "甲子", hour: "丙子"),
        Fixture(y: 2026, m: 3, d: 5, h: 18, year: "丙午", month: "辛卯", day: "戊寅", hour: "辛酉"),
        Fixture(y: 2026, m: 6, d: 24, h: 7, year: "丙午", month: "甲午", day: "己巳", hour: "戊辰"),
        Fixture(y: 2000, m: 1, d: 1, h: 0, year: "己卯", month: "丙子", day: "戊午", hour: "壬子"),
        Fixture(y: 1984, m: 2, d: 2, h: 12, year: "癸亥", month: "乙丑", day: "丙寅", hour: "甲午"),
        Fixture(y: 1900, m: 1, d: 6, h: 10, year: "己亥", month: "丁丑", day: "己卯", hour: "己巳"),
        Fixture(y: 2100, m: 12, d: 7, h: 14, year: "庚申", month: "戊子", day: "癸未", hour: "己未"),
        Fixture(y: 2023, m: 8, d: 8, h: 9, year: "癸卯", month: "庚申", day: "戊戌", hour: "丁巳"),
        Fixture(y: 2023, m: 8, d: 7, h: 3, year: "癸卯", month: "己未", day: "丁酉", hour: "壬寅"),
        Fixture(y: 2025, m: 1, d: 5, h: 5, year: "甲辰", month: "丁丑", day: "甲戌", hour: "丁卯"),
        Fixture(y: 2025, m: 1, d: 6, h: 5, year: "甲辰", month: "丁丑", day: "乙亥", hour: "己卯"),
        Fixture(y: 1995, m: 5, d: 15, h: 16, year: "乙亥", month: "辛巳", day: "丙午", hour: "丙申"),
        Fixture(y: 2010, m: 10, d: 10, h: 10, year: "庚寅", month: "丙戌", day: "癸巳", hour: "丁巳"),
        Fixture(y: 2026, m: 2, d: 4, h: 1, year: "丙午", month: "庚寅", day: "己酉", hour: "乙丑"),
        Fixture(y: 2026, m: 2, d: 3, h: 1, year: "乙巳", month: "己丑", day: "戊申", hour: "癸丑"),
        Fixture(y: 1988, m: 11, d: 7, h: 22, year: "戊辰", month: "癸亥", day: "丙寅", hour: "己亥"),
        Fixture(y: 2047, m: 7, d: 7, h: 7, year: "丁卯", month: "丁未", day: "壬申", hour: "甲辰"),
    ]

    func testFourPillarsAgainstFixtures() throws {
        for f in fixtures {
            let p = try GanzhiCalendar.fourPillars(year: f.y, month: f.m, day: f.d, hour: f.h)
            let label = "\(f.y)-\(f.m)-\(f.d) \(f.h):00"
            XCTAssertEqual(p.year.name, f.year, "年柱 @ \(label)")
            XCTAssertEqual(p.month.name, f.month, "月柱 @ \(label)")
            XCTAssertEqual(p.day.name, f.day, "日柱 @ \(label)")
            XCTAssertEqual(p.hour.name, f.hour, "时柱 @ \(label)")
        }
    }

    func testYearOutOfRangeThrows() {
        XCTAssertThrowsError(try GanzhiCalendar.fourPillars(year: 1899, month: 6, day: 1, hour: 12))
        XCTAssertThrowsError(try GanzhiCalendar.fourPillars(year: 2101, month: 6, day: 1, hour: 12))
    }

    // MARK: - 真太阳时校正

    private let shanghai = TimeZone(identifier: "Asia/Shanghai")!

    /// 同一日期、相差 1° 经度的两次校正应恰好相差 4 分钟（时差方程相消，只剩经度分量）。
    func testTrueSolarTimeLongitudeIsFourMinutesPerDegree() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = GanzhiCalendar.trueSolarTime(date, longitude: 116.0, timeZone: shanghai)
        let b = GanzhiCalendar.trueSolarTime(date, longitude: 117.0, timeZone: shanghai)
        XCTAssertEqual(b.timeIntervalSince(a), 240.0, accuracy: 0.001)
    }

    /// 位于时区标准经线上时，校正量仅为时差方程（|EoT| < 20 分钟）。
    func testTrueSolarTimeAtStandardMeridianIsEquationOfTimeOnly() {
        let date = Date(timeIntervalSince1970: 1_700_000_000) // 东八区标准经线 120°E
        let corrected = GanzhiCalendar.trueSolarTime(date, longitude: 120.0, timeZone: shanghai)
        XCTAssertLessThan(abs(corrected.timeIntervalSince(date)), 20 * 60)
    }

    /// 真太阳时校正可能把时柱推到相邻时辰（此处偏西经度使视太阳时更早）。
    func testTrueSolarTimeCanShiftHourPillar() throws {
        // 民用时正好落在午时（11:00–13:00）起始附近，偏西经度校正后应回退到巳时。
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 24
        comps.hour = 11; comps.minute = 5
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = shanghai
        let date = cal.date(from: comps)!

        let civil = try GanzhiCalendar.fourPillars(date: date, timeZone: shanghai)
        XCTAssertEqual(civil.hour.branch, .wu, "民用时应为午时")

        // 经度 90°E 远偏西于 120°E 标准经线：校正 (90-120)*4 = -120 分钟。
        let solar = try GanzhiCalendar.fourPillars(date: date, timeZone: shanghai, longitude: 90.0)
        XCTAssertEqual(solar.hour.branch, .si, "偏西校正后应回退到巳时")
    }

    /// 便捷重载与手动校正一致。
    func testFourPillarsLongitudeOverloadMatchesManualCorrection() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let manual = GanzhiCalendar.trueSolarTime(date, longitude: 116.4, timeZone: shanghai)
        let viaOverload = try GanzhiCalendar.fourPillars(date: date, timeZone: shanghai, longitude: 116.4)
        let viaManual = try GanzhiCalendar.fourPillars(date: manual, timeZone: shanghai)
        XCTAssertEqual(viaOverload, viaManual)
    }
}
