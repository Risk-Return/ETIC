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
}
