import XCTest
@testable import ETIC
import DivinationEngine

final class DivinationServiceTests: XCTestCase {

    private let testDate = Date(timeIntervalSinceReferenceDate: 804_556_400.0)

    // MARK: - 铜钱法

    func testCoinsMethodProducesValidBoard() throws {
        let input = makeInput(method: .coins, coinBacks: [2, 1, 2, 1, 2, 1])
        let board = try DivinationService.makeBoard(input)
        XCTAssertEqual(board.method, "铜钱")
        XCTAssertEqual(board.primary.lines.count, 6)
        XCTAssertFalse(board.primary.name.isEmpty)
    }

    func testCoinsWithAllYoungYangProducesQianHexagram() throws {
        let input = makeInput(method: .coins, coinBacks: [1, 1, 1, 1, 1, 1])
        let board = try DivinationService.makeBoard(input)
        XCTAssertEqual(board.primary.name, "乾为天")
        XCTAssertEqual(board.primary.upperTrigram, "乾")
        XCTAssertEqual(board.primary.lowerTrigram, "乾")
        XCTAssertEqual(board.movingPositions, [])
    }

    func testCoinsWithMovingLinesProducesChangedHexagram() throws {
        let input = makeInput(method: .coins, coinBacks: [3, 1, 1, 1, 1, 1])
        let board = try DivinationService.makeBoard(input)
        XCTAssertEqual(board.movingPositions, [1])
        XCTAssertNotNil(board.changed)
    }

    // MARK: - 报数法

    func testNumberMethodProducesValidBoard() throws {
        let input = makeInput(method: .number, upperNumber: 3, lowerNumber: 5)
        let board = try DivinationService.makeBoard(input)
        XCTAssertEqual(board.method, "报数")
        XCTAssertEqual(board.primary.lines.count, 6)
    }

    func testNumberMethodWithZeroUpperThrows() {
        let input = makeInput(method: .number, upperNumber: 0, lowerNumber: 5)
        XCTAssertThrowsError(try DivinationService.makeBoard(input)) { error in
            XCTAssertEqual(error as? DivinationService.ServiceError, .invalidNumbers)
        }
    }

    func testNumberMethodWithZeroLowerThrows() {
        let input = makeInput(method: .number, upperNumber: 3, lowerNumber: 0)
        XCTAssertThrowsError(try DivinationService.makeBoard(input)) { error in
            XCTAssertEqual(error as? DivinationService.ServiceError, .invalidNumbers)
        }
    }

    func testNumberMethodWithNegativeThrows() {
        let input = makeInput(method: .number, upperNumber: -1, lowerNumber: 5)
        XCTAssertThrowsError(try DivinationService.makeBoard(input))
    }

    // MARK: - 时间法

    func testTimeMethodProducesValidBoard() throws {
        let input = makeInput(method: .time)
        let board = try DivinationService.makeBoard(input)
        XCTAssertEqual(board.method, "时间")
        XCTAssertEqual(board.primary.lines.count, 6)
    }

    func testTimeMethodIsDeterministic() throws {
        let input = makeInput(method: .time)
        let board1 = try DivinationService.makeBoard(input)
        let board2 = try DivinationService.makeBoard(input)
        XCTAssertEqual(board1, board2, "相同输入应产生相同盘面")
    }

    // MARK: - 随机法

    func testRandomMethodProducesValidBoard() throws {
        let input = makeInput(method: .random)
        let board = try DivinationService.makeBoard(input)
        XCTAssertEqual(board.method, "随机")
        XCTAssertEqual(board.primary.lines.count, 6)
    }

    func testRandomMethodProducesDifferentResults() throws {
        let input = makeInput(method: .random)
        var boards: Set<String> = []
        for _ in 0..<20 {
            let board = try DivinationService.makeBoard(input)
            boards.insert(board.primary.name)
        }
        XCTAssertGreaterThan(boards.count, 1, "随机起卦应在多次调用中产生不同结果")
    }

    // MARK: - 日历越界

    func testCalendarOutOfRangeThrows() {
        let farPast = Date(timeIntervalSince1970: -1_000_000_000_000)
        let input = DivinationService.Input(
            method: .coins, question: "", category: .general,
            date: farPast, upperNumber: 0, lowerNumber: 0,
            coinBacks: [1, 1, 1, 1, 1, 1]
        )
        XCTAssertThrowsError(try DivinationService.makeBoard(input)) { error in
            XCTAssertEqual(error as? DivinationService.ServiceError, .calendarOutOfRange)
        }
    }

    // MARK: - 问题处理

    func testEmptyQuestionStoredAsNil() throws {
        let input = makeInput(method: .coins, question: "")
        let board = try DivinationService.makeBoard(input)
        XCTAssertNil(board.question)
    }

    func testWhitespaceOnlyQuestionStoredAsNil() throws {
        let input = makeInput(method: .coins, question: "   ")
        let board = try DivinationService.makeBoard(input)
        XCTAssertNil(board.question)
    }

    func testQuestionIsTrimmed() throws {
        let input = makeInput(method: .coins, question: "  求职  ")
        let board = try DivinationService.makeBoard(input)
        XCTAssertEqual(board.question, "求职")
    }

    // MARK: - 类别传入

    func testCategoryIsPassedThrough() throws {
        for cat in QuestionCategory.allCases {
            let input = makeInput(method: .coins, category: cat)
            let board = try DivinationService.makeBoard(input)
            XCTAssertEqual(board.category, cat.rawValue)
        }
    }

    // MARK: - 时区

    func testDifferentTimeZoneAffectsPillars() throws {
        var dc = DateComponents()
        dc.year = 2026; dc.month = 7; dc.day = 3; dc.hour = 14; dc.minute = 0
        dc.timeZone = TimeZone(secondsFromGMT: 0)
        let date = Calendar(identifier: .gregorian).date(from: dc)!
        let input = makeInput(method: .coins, date: date)
        let shanghai = try DivinationService.makeBoard(input, timeZone: TimeZone(identifier: "Asia/Shanghai")!)
        let tokyo = try DivinationService.makeBoard(input, timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        XCTAssertNotEqual(shanghai.castTime.hourPillar, tokyo.castTime.hourPillar, "UTC 14:00 → 上海 亥时 / 东京 子时，时辰不同")
    }

    // MARK: - 盘面契约

    func testBoardSchemaVersionIsCorrect() throws {
        let board = try DivinationService.makeBoard(makeInput(method: .coins))
        XCTAssertEqual(board.version, DivinationBoard.schemaVersion)
        XCTAssertEqual(board.version, "1.0.0")
    }

    func testBoardContainsFourPillars() throws {
        let board = try DivinationService.makeBoard(makeInput(method: .coins))
        XCTAssertFalse(board.castTime.yearPillar.isEmpty)
        XCTAssertFalse(board.castTime.monthPillar.isEmpty)
        XCTAssertFalse(board.castTime.dayPillar.isEmpty)
        XCTAssertFalse(board.castTime.hourPillar.isEmpty)
    }

    func testBoardContainsVoidBranches() throws {
        let board = try DivinationService.makeBoard(makeInput(method: .coins))
        XCTAssertEqual(board.castTime.voidBranches.count, 2)
    }

    // MARK: - ServiceError

    func testInvalidNumbersErrorDescription() {
        XCTAssertFalse(DivinationService.ServiceError.invalidNumbers.errorDescription!.isEmpty)
    }

    func testCalendarOutOfRangeErrorDescription() {
        XCTAssertFalse(DivinationService.ServiceError.calendarOutOfRange.errorDescription!.isEmpty)
    }
}

// MARK: - Helpers

private extension DivinationServiceTests {
    func makeInput(
        method: CastMethod = .coins,
        question: String = "测试",
        category: QuestionCategory = .general,
        date: Date? = nil,
        upperNumber: Int = 3,
        lowerNumber: Int = 5,
        coinBacks: [Int] = [2, 1, 2, 1, 2, 1]
    ) -> DivinationService.Input {
        DivinationService.Input(
            method: method,
            question: question,
            category: category,
            date: date ?? testDate,
            upperNumber: upperNumber,
            lowerNumber: lowerNumber,
            coinBacks: coinBacks
        )
    }
}
