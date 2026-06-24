import XCTest
@testable import DivinationEngine

/// 排盘流水线端到端测试（经典卦例 + 手工核验）。
final class EngineTests: XCTestCase {

    /// 构造测试用四柱：年甲子、月丙寅(寅月)、日甲子、时甲子。
    private func pillars(month: String = "丙寅", day: String = "甲子") -> GanzhiCalendar.FourPillars {
        GanzhiCalendar.FourPillars(
            year: Ganzhi(name: "甲子")!,
            month: Ganzhi(name: month)!,
            day: Ganzhi(name: day)!,
            hour: Ganzhi(name: "甲子")!
        )
    }

    // MARK: - 乾为天（无动爻）整盘核验

    func testQianForHeavenFullBoard() {
        let cast = CastResult(method: .manual, lines: Array(repeating: .youngYang, count: 6))
        let board = LiuyaoEngine.cast(cast, pillars: pillars(), category: .general)

        XCTAssertEqual(board.primary.name, "乾为天")
        XCTAssertEqual(board.primary.palace, "乾宫")
        XCTAssertEqual(board.primary.palaceElement, "金")
        XCTAssertEqual(board.primary.worldPosition, 6)
        XCTAssertEqual(board.primary.responsePosition, 3)
        XCTAssertNil(board.changed, "无动爻则无变卦")
        XCTAssertEqual(board.movingPositions, [])

        let lines = board.primary.lines
        // 纳甲（初→上）
        XCTAssertEqual(lines.map { $0.stem + $0.branch },
                       ["甲子", "甲寅", "甲辰", "壬午", "壬申", "壬戌"])
        // 六亲（自下而上）：子孙 妻财 父母 官鬼 兄弟 父母
        XCTAssertEqual(lines.map(\.sixRelative),
                       ["子孙", "妻财", "父母", "官鬼", "兄弟", "父母"])
        // 六神（甲日起青龙，初→上）
        XCTAssertEqual(lines.map { $0.sixGod ?? "" },
                       ["青龙", "朱雀", "勾陈", "螣蛇", "白虎", "玄武"])
        // 旬空（甲子旬空戌亥）：仅上爻戌土空
        XCTAssertEqual(lines.map(\.isVoid), [false, false, false, false, false, true])
        // 旺衰（寅月，木令）
        XCTAssertEqual(lines.map(\.strength),
                       ["休", "旺", "死", "相", "囚", "死"])
        // 世应
        XCTAssertTrue(lines[5].isWorld)
        XCTAssertTrue(lines[2].isResponse)
    }

    // MARK: - 带动爻：乾初爻动 → 变天风姤

    func testMovingLineProducesChangedHexagram() {
        var values: [LineValue] = Array(repeating: .youngYang, count: 6)
        values[0] = .oldYang // 初爻动
        let cast = CastResult(method: .manual, lines: values)
        let board = LiuyaoEngine.cast(cast, pillars: pillars())

        XCTAssertEqual(board.movingPositions, [1])
        XCTAssertEqual(board.primary.name, "乾为天")
        XCTAssertNotNil(board.changed)
        XCTAssertEqual(board.changed?.name, "天风姤")
        // 变卦六亲以本卦宫（乾金）为准：初爻变为巽下，纳甲初爻辛丑(土) → 父母
        XCTAssertEqual(board.changed?.lines.first?.stem, "辛")
        XCTAssertEqual(board.changed?.lines.first?.branch, "丑")
        XCTAssertEqual(board.changed?.lines.first?.sixRelative, "父母")
        // 变卦不带六神
        XCTAssertNil(board.changed?.lines.first?.sixGod)
        // 本卦动爻标记
        XCTAssertTrue(board.primary.lines[0].moving)
        XCTAssertEqual(board.primary.lines[0].value, "老阳")
    }

    // MARK: - 用神建议

    func testUseGodForWealth() {
        let cast = CastResult(method: .manual, lines: Array(repeating: .youngYang, count: 6))
        let board = LiuyaoEngine.cast(cast, pillars: pillars(), category: .wealth)
        XCTAssertEqual(board.useGod?.relative, "妻财")
        // 乾卦妻财为寅木，在二爻
        XCTAssertEqual(board.useGod?.positions, [2])
    }

    // MARK: - JSON 契约可序列化 / 往返

    func testBoardJSONRoundTrip() throws {
        let cast = Caster.fromCoinBacks([3, 1, 2, 1, 2, 0])
        let pillars = try GanzhiCalendar.fourPillars(year: 2026, month: 6, day: 24, hour: 7)
        let board = LiuyaoEngine.cast(cast, pillars: pillars,
                                      gregorianDescription: "2026-06-24 07:00",
                                      question: "测试", category: .career)
        let data = try board.jsonData()
        let decoded = try JSONDecoder().decode(DivinationBoard.self, from: data)
        XCTAssertEqual(decoded, board)
        XCTAssertEqual(decoded.version, DivinationBoard.schemaVersion)
        // 含动爻则必有变卦
        XCTAssertFalse(decoded.movingPositions.isEmpty)
        XCTAssertNotNil(decoded.changed)
    }

    // MARK: - 全 64 卦排盘不崩溃且自洽

    func testAllHexagramsBoardConsistency() {
        let p = pillars()
        for code in 0..<64 {
            let hex = Hexagram(code: code)
            let cast = CastResult(method: .manual, lines: hex.lines.map { $0 == .yang ? .youngYang : .youngYin })
            let board = LiuyaoEngine.cast(cast, pillars: p, category: .general)
            XCTAssertEqual(board.primary.lines.count, 6)
            XCTAssertNil(board.changed)
            // 世应位互不相同且在 1...6
            let w = board.primary.worldPosition
            let r = board.primary.responsePosition
            XCTAssertTrue((1...6).contains(w))
            XCTAssertTrue((1...6).contains(r))
            XCTAssertNotEqual(w, r)
            XCTAssertEqual(abs(w - r), 3, "世应相隔三位")
        }
    }
}
