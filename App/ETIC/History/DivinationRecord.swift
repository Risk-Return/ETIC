import Foundation
import SwiftData
import DivinationEngine

/// 一条历史卦例（SwiftData 本地持久化，iOS 17+）。
///
/// 只存引擎算好的盘面 JSON 与解读对话，**不做任何术数计算**；盘面为只读快照。
/// `key` 由盘面内容派生（跨启动稳定），用于去重与「起卦 → 解读」回写同一条记录。
@Model
final class DivinationRecord {
    /// 内容派生的稳定主键（同一盘面只存一条）。
    @Attribute(.unique) var key: String
    var createdAt: Date
    /// 起卦方法（如「铜钱」）。
    var method: String
    /// 所问之事（可空）。
    var question: String
    /// 事项类别原始值（如「考学」）。
    var categoryRaw: String
    var primaryName: String
    var changedName: String?
    var isFavorite: Bool
    /// 盘面契约 JSON（`DivinationBoard` 编码）。
    var boardData: Data
    /// 解读对话 JSON（`[StoredTurn]` 编码）。
    var conversationData: Data

    init(
        key: String,
        createdAt: Date,
        method: String,
        question: String,
        categoryRaw: String,
        primaryName: String,
        changedName: String?,
        isFavorite: Bool = false,
        boardData: Data,
        conversationData: Data
    ) {
        self.key = key
        self.createdAt = createdAt
        self.method = method
        self.question = question
        self.categoryRaw = categoryRaw
        self.primaryName = primaryName
        self.changedName = changedName
        self.isFavorite = isFavorite
        self.boardData = boardData
        self.conversationData = conversationData
    }
}

extension DivinationRecord {
    /// 解码回盘面契约（失败返回 nil）。
    var board: DivinationBoard? {
        try? JSONDecoder().decode(DivinationBoard.self, from: boardData)
    }

    /// 解码解读对话（失败返回空）。
    var turns: [StoredTurn] {
        (try? JSONDecoder().decode([StoredTurn].self, from: conversationData)) ?? []
    }

    /// 列表标题：本卦（→ 变卦）。
    var title: String {
        if let changed = changedName, !changed.isEmpty {
            return "\(primaryName) → \(changed)"
        }
        return primaryName
    }
}

/// 解读对话中的一条（持久化用），与 `InterpretationViewModel.Turn` 对应。
struct StoredTurn: Codable, Hashable, Identifiable {
    enum Role: String, Codable { case user, master }
    var id: UUID
    var role: Role
    var text: String

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}
