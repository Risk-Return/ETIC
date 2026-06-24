import Foundation
import SwiftUI
import DivinationEngine

/// 解读对话状态机：首轮解读 + 多轮追问，全程携带同一盘面上下文。
///
/// 不做任何术数计算；盘面来自引擎、只读。追问只在同一盘面上延展，不重新起卦。
@MainActor
final class InterpretationViewModel: ObservableObject {

    struct Turn: Identifiable, Hashable {
        enum Role { case user, master }
        let id = UUID()
        let role: Role
        var text: String
    }

    let board: DivinationBoard

    @Published private(set) var turns: [Turn] = []
    @Published private(set) var isStreaming = false
    @Published var draft: String = ""
    @Published var errorMessage: String?

    private let service: LLMService
    private var streamTask: Task<Void, Never>?

    init(board: DivinationBoard, service: LLMService = LLMService()) {
        self.board = board
        self.service = service
    }

    var canSend: Bool {
        !isStreaming && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 首轮解读：进入页面时调用一次。
    func startIfNeeded() {
        guard turns.isEmpty, !isStreaming else { return }
        let master = appendMaster()
        run(stream: service.interpret(board: board), into: master.id)
    }

    /// 多轮追问：发送输入框内容。
    func send() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isStreaming else { return }
        draft = ""
        turns.append(Turn(role: .user, text: question))

        let history = buildHistory()
        let master = appendMaster()
        run(stream: service.chat(board: board, messages: history), into: master.id)
    }

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    // MARK: - Helpers

    private func appendMaster() -> Turn {
        let turn = Turn(role: .master, text: "")
        turns.append(turn)
        return turn
    }

    /// 把已完成的对话整理为后端所需的消息历史（不含正在生成的占位条）。
    private func buildHistory() -> [LLMService.ChatMessage] {
        turns.compactMap { turn in
            switch turn.role {
            case .user:
                return LLMService.ChatMessage(role: .user, content: turn.text)
            case .master:
                guard !turn.text.isEmpty else { return nil }
                return LLMService.ChatMessage(role: .assistant, content: turn.text)
            }
        }
    }

    private func run(stream: AsyncThrowingStream<String, Error>, into id: UUID) {
        errorMessage = nil
        isStreaming = true
        streamTask = Task { [weak self] in
            do {
                for try await delta in stream {
                    guard let self else { return }
                    if let idx = self.turns.firstIndex(where: { $0.id == id }) {
                        self.turns[idx].text += delta
                    }
                }
            } catch is CancellationError {
                // 用户主动取消，保留已生成文本。
            } catch {
                self?.handle(error: error, masterID: id)
            }
            self?.isStreaming = false
        }
    }

    private func handle(error: Error, masterID: UUID) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        // 若占位条仍为空，移除它以免留下空气泡。
        if let idx = turns.firstIndex(where: { $0.id == masterID }), turns[idx].text.isEmpty {
            turns.remove(at: idx)
        }
    }
}
