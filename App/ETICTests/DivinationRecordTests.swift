import XCTest
import SwiftData
@testable import ETIC
import DivinationEngine

@MainActor
final class DivinationRecordTests: XCTestCase {
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

    // MARK: - board 解码

    func testBoardDecodingRoundTrip() throws {
        let board = try makeTestBoard(category: .career)
        let record = makeRecord(board: board)
        let decoded = record.board
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.primary.name, board.primary.name)
        XCTAssertEqual(decoded?.method, board.method)
        XCTAssertEqual(decoded?.category, board.category)
    }

    func testBoardDecodingCorruptedDataReturnsNil() {
        let record = DivinationRecord(
            key: "test",
            createdAt: Date(),
            method: "铜钱",
            question: "问",
            categoryRaw: "综合",
            primaryName: "乾为天",
            changedName: nil,
            boardData: Data([0xFF, 0xFE, 0xFD]),
            conversationData: Data("[]".utf8)
        )
        XCTAssertNil(record.board)
    }

    // MARK: - turns 解码

    func testTurnsDecoding() throws {
        let board = try makeTestBoard(category: .general)
        let record = makeRecord(board: board)
        let turns = [
            StoredTurn(role: .user, text: "问工作"),
            StoredTurn(role: .master, text: "官鬼持世，利于求名。"),
        ]
        let encoded = try JSONEncoder().encode(turns)
        record.conversationData = encoded
        let decoded = record.turns
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].role, .user)
        XCTAssertEqual(decoded[1].role, .master)
        XCTAssertEqual(decoded[0].text, "问工作")
    }

    func testTurnsDecodingEmptyDataReturnsEmpty() throws {
        let board = try makeTestBoard(category: .general)
        let record = makeRecord(board: board)
        record.conversationData = Data("[]".utf8)
        XCTAssertEqual(record.turns.count, 0)
    }

    func testTurnsDecodingCorruptedDataReturnsEmpty() throws {
        let board = try makeTestBoard(category: .general)
        let record = makeRecord(board: board)
        record.conversationData = Data([0x00, 0x01])
        XCTAssertEqual(record.turns.count, 0)
    }

    // MARK: - title

    func testTitleWithChangedHexagram() throws {
        let board = try makeTestBoard(category: .general)
        let record = makeRecord(board: board)
        if let changed = board.changed?.name {
            XCTAssertTrue(record.title.contains("→"))
            XCTAssertTrue(record.title.contains(changed))
        }
    }

    func testTitleWithoutChangedHexagram() throws {
        let board = try makeTestBoardNoMoving(category: .general)
        let record = makeRecord(board: board)
        XCTAssertEqual(record.title, board.primary.name)
        XCTAssertFalse(record.title.contains("→"))
    }

    // MARK: - 初始化属性

    func testRecordPropertiesAreSetCorrectly() throws {
        let board = try makeTestBoard(category: .career, question: "问事业")
        let record = makeRecord(board: board)
        XCTAssertEqual(record.method, board.method)
        XCTAssertEqual(record.question, "问事业")
        XCTAssertEqual(record.categoryRaw, "事业")
        XCTAssertEqual(record.primaryName, board.primary.name)
        XCTAssertFalse(record.isFavorite)
    }
}

// MARK: - StoredTurn

final class StoredTurnTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let turn = StoredTurn(role: .user, text: "何时应？")
        let data = try JSONEncoder().encode(turn)
        let decoded = try JSONDecoder().decode(StoredTurn.self, from: data)
        XCTAssertEqual(decoded.role, .user)
        XCTAssertEqual(decoded.text, "何时应？")
    }

    func testIdentifiable() {
        let t1 = StoredTurn(role: .user, text: "A")
        let t2 = StoredTurn(role: .user, text: "A")
        XCTAssertNotEqual(t1.id, t2.id)
    }

    func testHashable() {
        let t1 = StoredTurn(role: .user, text: "A")
        let t2 = StoredTurn(role: .user, text: "A")
        var set = Set<StoredTurn>()
        set.insert(t1)
        set.insert(t2)
        let data1 = try! JSONEncoder().encode(t1)
        let data2 = try! JSONEncoder().encode(t2)
        XCTAssertNotEqual(data1, data2, "不同 UUID 应产生不同 JSON")
    }

    func testRolesEncodeCorrectly() throws {
        let user = StoredTurn(role: .user, text: "问")
        let master = StoredTurn(role: .master, text: "答")
        let userData = try JSONEncoder().encode(user)
        let masterData = try JSONEncoder().encode(master)
        XCTAssertTrue(String(data: userData, encoding: .utf8)!.contains("user"))
        XCTAssertTrue(String(data: masterData, encoding: .utf8)!.contains("master"))
    }
}

// MARK: - Helpers

private extension DivinationRecordTests {
    func makeRecord(
        board: DivinationBoard,
        key: String? = nil,
        turns: [StoredTurn] = []
    ) -> DivinationRecord {
        let recordKey = key ?? HistoryStore.key(for: board)
        let boardData = (try? JSONEncoder().encode(board)) ?? Data()
        let conversationData = (try? JSONEncoder().encode(turns)) ?? Data("[]".utf8)
        return DivinationRecord(
            key: recordKey,
            createdAt: Date(),
            method: board.method,
            question: board.question ?? "",
            categoryRaw: board.category ?? "",
            primaryName: board.primary.name,
            changedName: board.changed?.name,
            boardData: boardData,
            conversationData: conversationData
        )
    }

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

    func makeTestBoardNoMoving(
        category: QuestionCategory = .general
    ) throws -> DivinationBoard {
        let input = DivinationService.Input(
            method: .coins,
            question: "无动爻测试",
            category: category,
            date: Date(timeIntervalSinceReferenceDate: 804_556_400.0),
            upperNumber: 3,
            lowerNumber: 5,
            coinBacks: [1, 1, 1, 1, 1, 1]
        )
        return try DivinationService.makeBoard(input)
    }
}
