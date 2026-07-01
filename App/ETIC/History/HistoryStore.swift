import Foundation
import SwiftData
import DivinationEngine

/// 历史卦例的读写封装（基于 SwiftData `ModelContext`）。
///
/// 起卦时登记一条记录；解读产生对话后回写同一条（按内容派生的 `key` 去重）。
/// 本层只做持久化，不做任何术数计算。
enum HistoryStore {

    /// 由盘面内容派生跨启动稳定的主键（Swift `Hasher` 每进程随机，不能用于持久化）。
    static func key(for board: DivinationBoard) -> String {
        let moving = board.movingPositions.map(String.init).joined(separator: ",")
        return [
            board.method,
            board.castTime.gregorian,
            board.primary.name,
            board.changed?.name ?? "",
            moving,
            board.question ?? "",
        ].joined(separator: "|")
    }

    /// 登记一次起卦（已存在则返回原记录，不重复插入）。
    @discardableResult
    static func recordCast(_ context: ModelContext, board: DivinationBoard) -> DivinationRecord? {
        let k = key(for: board)
        if let existing = fetch(context, key: k) { return existing }
        guard let data = try? JSONEncoder().encode(board) else { return nil }
        let record = DivinationRecord(
            key: k,
            createdAt: Date(),
            method: board.method,
            question: board.question ?? "",
            categoryRaw: board.category ?? "",
            primaryName: board.primary.name,
            changedName: board.changed?.name,
            boardData: data,
            conversationData: Data("[]".utf8)
        )
        context.insert(record)
        try? context.save()
        return record
    }

    /// 回写解读对话（确保记录存在）。
    static func saveConversation(
        _ context: ModelContext, board: DivinationBoard, turns: [StoredTurn]
    ) {
        guard let record = recordCast(context, board: board),
              let data = try? JSONEncoder().encode(turns) else { return }
        record.conversationData = data
        try? context.save()
    }

    static func toggleFavorite(_ context: ModelContext, _ record: DivinationRecord) {
        record.isFavorite.toggle()
        try? context.save()
    }

    static func delete(_ context: ModelContext, _ record: DivinationRecord) {
        context.delete(record)
        try? context.save()
    }

    private static func fetch(_ context: ModelContext, key: String) -> DivinationRecord? {
        var descriptor = FetchDescriptor<DivinationRecord>(
            predicate: #Predicate { $0.key == key }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
