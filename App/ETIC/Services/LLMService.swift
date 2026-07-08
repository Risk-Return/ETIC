import Foundation
import DivinationEngine

/// 解读后端客户端：把端上算好的盘面 JSON 发给后端代理，按 SSE 流式接收解读增量。
///
/// 客户端**不持有 LLM key、不直连模型**，一律走后端（见 `Backend/`）。本层只做网络与
/// SSE 解析，不做任何术数计算。
struct LLMService {

    enum ServiceError: LocalizedError {
        case badURL
        case http(Int)
        case upstream(String)
        case insufficientCredits
        case questionLimit

        var errorDescription: String? {
            switch self {
            case .badURL: return L10n.Error.badURL
            case .http(let code): return L10n.Error.httpError.replacingOccurrences(of: "%d", with: "\(code)")
            case .upstream(let message): return message
            case .insufficientCredits: return L10n.Error.insufficientCredits
            case .questionLimit: return L10n.Error.questionLimit
            }
        }
    }

    /// 后端地址。模拟器可用 localhost；真机改成局域网 IP 或线上地址。
    /// 可经 Info.plist 的 `ETIC_BACKEND_BASE_URL` 覆盖，便于切换环境。
    var baseURL: URL

    init(baseURL: URL? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else if
            let raw = Bundle.main.object(forInfoDictionaryKey: "ETIC_BACKEND_BASE_URL") as? String,
            let url = URL(string: raw)
        {
            self.baseURL = url
        } else {
            self.baseURL = URL(string: "https://deepwitai.cn/app/etic")!
        }
    }

    /// 当前界面语言（如 `zh-Hans` / `en`），随请求下发，用于后端内容审核拒绝文案与解读作答语言。
    private var currentLocale: String {
        UserDefaults.standard.string(forKey: "app.language") ?? "en"
    }

    /// 首轮解读：盘面 → 流式断语。
    func interpret(board: DivinationBoard) -> AsyncThrowingStream<String, Error> {
        let body = InterpretBody(board: board, locale: currentLocale)
        return stream(path: "/v1/interpret", body: body)
    }

    /// 多轮追问：盘面 + 历史对话 → 流式回复。
    func chat(board: DivinationBoard, messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        let body = ChatBody(board: board, messages: messages, locale: currentLocale)
        return stream(path: "/v1/chat", body: body)
    }

    /// 经文检索：盘面 → 本卦/动爻/变卦相关周易经文（供展示「经文参考」）。
    ///
    /// 与解读流分离，一次性返回；后端关闭 RAG 或库不可达时返回空列表（不影响解读）。
    func grounding(board: DivinationBoard) async throws -> GroundingResult {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/grounding"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let header = await AuthService.shared.authHeader {
            request.setValue(header, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(GroundingBody(board: board))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw ServiceError.http(http.statusCode)
        }
        return try JSONDecoder().decode(GroundingResult.self, from: data)
    }

    // MARK: - Wire types

    struct ChatMessage: Codable, Hashable {
        enum Role: String, Codable { case user, assistant }
        let role: Role
        let content: String
    }

    /// 一条可展示的经文片段，对齐后端 `GroundingItem`。
    struct GroundingItem: Decodable, Hashable, Identifiable {
        let ref: String             // 出处，如「《山火贲》卦辞」
        let hexagramName: String
        let hexagramShort: String
        let docType: String         // judgment | line | tuan
        let linePosition: Int?
        let content: String

        var id: String { ref + content }
    }

    /// 经文检索结果，对齐后端 `GroundingResponse`。
    struct GroundingResult: Decodable {
        let enabled: Bool
        let items: [GroundingItem]
    }

    private struct InterpretBody: Encodable {
        let board: DivinationBoard
        let locale: String
    }

    private struct ChatBody: Encodable {
        let board: DivinationBoard
        let messages: [ChatMessage]
        let locale: String
    }

    private struct GroundingBody: Encodable {
        let board: DivinationBoard
    }

    private struct SSEPayload: Decodable {
        let delta: String?
        let error: String?
    }

    // MARK: - SSE

    private func stream<Body: Encodable>(path: String, body: Body) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent(path))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    if let header = await AuthService.shared.authHeader {
                        request.setValue(header, forHTTPHeaderField: "Authorization")
                    }
                    request.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                        if http.statusCode == 402 {
                            throw ServiceError.insufficientCredits
                        }
                        if http.statusCode == 429 {
                            throw ServiceError.questionLimit
                        }
                        throw ServiceError.http(http.statusCode)
                    }

                    let decoder = JSONDecoder()
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let data = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                        if data == "[DONE]" { break }
                        guard let payload = try? decoder.decode(SSEPayload.self, from: Data(data.utf8)) else { continue }
                        if let error = payload.error {
                            throw ServiceError.upstream(error)
                        }
                        if let delta = payload.delta, !delta.isEmpty {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
