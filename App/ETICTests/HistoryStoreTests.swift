import XCTest
import SwiftData
@testable import ETIC
import DivinationEngine

@MainActor
final class HistoryStoreTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: DivinationRecord.self, configurations: config)
        context = container.mainContext
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    // MARK: - key(for:)

    func testKeyIsDeterministic() throws {
        let board = try makeTestBoard(category: .general)
        let key1 = HistoryStore.key(for: board)
        let key2 = HistoryStore.key(for: board)
        XCTAssertEqual(key1, key2)
    }

    func testKeyDiffersForDifferentBoards() throws {
        let board1 = try makeTestBoard(category: .career, method: .coins)
        let board2 = try makeTestBoard(category: .wealth, method: .number)
        XCTAssertNotEqual(HistoryStore.key(for: board1), HistoryStore.key(for: board2))
    }

    func testKeyIncludesMethodAndQuestion() throws {
        let a = try makeTestBoard(category: .general, method: .coins, question: "找工作")
        let b = try makeTestBoard(category: .general, method: .number, question: "找工作")
        let c = try makeTestBoard(category: .general, method: .coins, question: "求财")
        XCTAssertNotEqual(HistoryStore.key(for: a), HistoryStore.key(for: b), "不同起卦方法应有不同 key")
        XCTAssertNotEqual(HistoryStore.key(for: a), HistoryStore.key(for: c), "不同问题应有不同 key")
    }

    // MARK: - recordCast

    func testRecordCastCreatesRecord() throws {
        let board = try makeTestBoard(category: .general, method: .coins)
        let record = HistoryStore.recordCast(context, board: board)
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.primaryName, board.primary.name)
        XCTAssertEqual(record?.method, "铜钱")
        XCTAssertEqual(record?.isFavorite, false)
        XCTAssertEqual(record?.categoryRaw, "综合")
        XCTAssertEqual(record?.question, "测试问题")
    }

    func testRecordCastIsIdempotent() throws {
        let board = try makeTestBoard(category: .general)
        let r1 = HistoryStore.recordCast(context, board: board)
        let r2 = HistoryStore.recordCast(context, board: board)
        XCTAssertNotNil(r1)
        XCTAssertNotNil(r2)
        XCTAssertEqual(r1?.key, r2?.key)

        let all = try fetchAll()
        XCTAssertEqual(all.count, 1, "同一盘面不应重复插入")
    }

    func testRecordCastDifferentBoardsCreatesSeparateRecords() throws {
        let b1 = try makeTestBoard(category: .career, method: .coins, question: "A")
        let b2 = try makeTestBoard(category: .wealth, method: .random, question: "B")
        HistoryStore.recordCast(context, board: b1)
        HistoryStore.recordCast(context, board: b2)
        let all = try fetchAll()
        XCTAssertEqual(all.count, 2)
    }

    // MARK: - saveConversation

    func testSaveConversationWritesTurns() throws {
        let board = try makeTestBoard(category: .general)
        let record = HistoryStore.recordCast(context, board: board)!
        XCTAssertTrue(record.turns.isEmpty)

        let turns = [
            StoredTurn(role: .user, text: "此卦如何？"),
            StoredTurn(role: .master, text: "吉，宜动不宜静。"),
        ]
        HistoryStore.saveConversation(context, board: board, turns: turns)
        XCTAssertEqual(record.turns.count, 2)
        XCTAssertEqual(record.turns[0].role, .user)
        XCTAssertEqual(record.turns[1].text, "吉，宜动不宜静。")
    }

    func testSaveConversationEmptyTurns() throws {
        let board = try makeTestBoard(category: .general)
        let record = HistoryStore.recordCast(context, board: board)!
        HistoryStore.saveConversation(context, board: board, turns: [])
        XCTAssertEqual(record.turns.count, 0)
    }

    func testSaveConversationCreatesRecordIfMissing() throws {
        let board = try makeTestBoard(category: .general)
        let turns = [StoredTurn(role: .user, text: "问")]
        HistoryStore.saveConversation(context, board: board, turns: turns)
        let all = try fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].turns.count, 1)
    }

    // MARK: - toggleFavorite

    func testToggleFavorite() throws {
        let board = try makeTestBoard(category: .general)
        let record = HistoryStore.recordCast(context, board: board)!
        XCTAssertFalse(record.isFavorite)

        HistoryStore.toggleFavorite(context, record)
        XCTAssertTrue(record.isFavorite)

        HistoryStore.toggleFavorite(context, record)
        XCTAssertFalse(record.isFavorite)
    }

    // MARK: - delete

    func testDeleteRemovesRecord() throws {
        let board = try makeTestBoard(category: .general)
        let record = HistoryStore.recordCast(context, board: board)!
        HistoryStore.delete(context, record)
        let all = try fetchAll()
        XCTAssertTrue(all.isEmpty)
    }
}

// MARK: - Helpers

private extension HistoryStoreTests {
    func makeTestBoard(
        category: QuestionCategory = .general,
        method: CastMethod = .coins,
        question: String = "测试问题"
    ) throws -> DivinationBoard {
        let input = DivinationService.Input(
            method: method,
            question: question,
            category: category,
            date: Date(timeIntervalSinceReferenceDate: 804_556_400.0),
            upperNumber: 3,
            lowerNumber: 5,
            coinBacks: [2, 1, 2, 1, 2, 1]
        )
        return try DivinationService.makeBoard(input)
    }

    func fetchAll() throws -> [DivinationRecord] {
        try context.fetch(FetchDescriptor<DivinationRecord>())
    }
}
