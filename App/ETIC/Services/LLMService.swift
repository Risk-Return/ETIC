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

        var errorDescription: String? {
            switch self {
            case .badURL: return "后端地址无效。"
            case .http(let code): return "后端返回错误（HTTP \(code)）。"
            case .upstream(let message): return message
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
            self.baseURL = URL(string: "http://localhost:8000")!
        }
    }

    /// 首轮解读：盘面 → 流式断语。
    func interpret(board: DivinationBoard) -> AsyncThrowingStream<String, Error> {
        let body = InterpretBody(board: board)
        return stream(path: "/v1/interpret", body: body)
    }

    /// 多轮追问：盘面 + 历史对话 → 流式回复。
    func chat(board: DivinationBoard, messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        let body = ChatBody(board: board, messages: messages)
        return stream(path: "/v1/chat", body: body)
    }

    // MARK: - Wire types

    struct ChatMessage: Codable, Hashable {
        enum Role: String, Codable { case user, assistant }
        let role: Role
        let content: String
    }

    private struct InterpretBody: Encodable {
        let board: DivinationBoard
    }

    private struct ChatBody: Encodable {
        let board: DivinationBoard
        let messages: [ChatMessage]
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
                    request.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
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
