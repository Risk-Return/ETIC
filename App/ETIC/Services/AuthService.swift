import Foundation
import AuthenticationServices

/// Apple Sign In + 后端会话管理。
///
/// 流程：
/// 1. iOS Sign in with Apple 获取 `identityToken` + `authorizationCode`。
/// 2. 将 identityToken 提交给后端 `POST /v1/auth/apple`。
/// 3. 后端验签后返回 `sessionToken`（JWT）+ 账号状态。
/// 4. sessionToken 存 Keychain，后续请求携带 `Authorization: Bearer`。
@MainActor
final class AuthService: ObservableObject {

    static let shared = AuthService()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var accountStatus: AccountStatus?
    @Published var errorMessage: String?

    let baseURL: URL
    private let keychainKey = "etic.session_token"

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
        if let token = loadSessionToken() {
            self.sessionToken = token
            self.isAuthenticated = true
        }
    }

    private var sessionToken: String?

    /// Authorization header value for authenticated requests, or nil.
    var authHeader: String? {
        guard let token = sessionToken else { return nil }
        return "Bearer \(token)"
    }

    // MARK: - Sign in with Apple

    /// Handle Apple Sign In authorization result.
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8)
            else {
                errorMessage = "Failed to get Apple identity token."
                return
            }

            let email = credential.email
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            await authenticateWithBackend(
                identityToken: identityToken,
                email: email,
                fullName: fullName.isEmpty ? nil : fullName
            )

        case .failure(let error):
            errorMessage = (error as? ASAuthorizationError)?.localizedDescription
                ?? error.localizedDescription
        }
    }

    private func authenticateWithBackend(
        identityToken: String, email: String?, fullName: String?
    ) async {
        errorMessage = nil
        do {
            let body = AppleAuthBody(
                identityToken: identityToken,
                email: email,
                fullName: fullName
            )
            let data = try JSONEncoder().encode(body)

            var request = URLRequest(url: baseURL.appendingPathComponent("/v1/auth/apple"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data

            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                errorMessage = "Sign in failed (HTTP \(code))."
                return
            }

            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: responseData)
            sessionToken = authResponse.sessionToken
            accountStatus = authResponse.account
            isAuthenticated = true
            saveSessionToken(authResponse.sessionToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Fetch account status

    /// Refresh account status from backend.
    func refreshAccountStatus() async {
        guard let header = authHeader else { return }
        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("/v1/account/me"))
            request.httpMethod = "GET"
            request.setValue(header, forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }
            if http.statusCode == 401 {
                signOut()
                return
            }
            guard http.statusCode == 200 else { return }
            accountStatus = try JSONDecoder().decode(AccountStatus.self, from: data)
        } catch {
            // Silent failure on refresh.
        }
    }

    // MARK: - Test login (dev mode only)

    /// Test login: calls POST /v1/auth/test on the backend.
    /// Only works when backend has ETIC_DEV_MODE=true.
    func testLogin() async {
        errorMessage = nil
        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("/v1/auth/test"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "No response from server."
                return
            }
            if http.statusCode == 403 {
                errorMessage = "Test login is disabled. Set ETIC_DEV_MODE=true on the backend."
                return
            }
            guard http.statusCode == 200 else {
                errorMessage = "Test login failed (HTTP \(http.statusCode))."
                return
            }

            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: responseData)
            sessionToken = authResponse.sessionToken
            accountStatus = authResponse.account
            isAuthenticated = true
            saveSessionToken(authResponse.sessionToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign out

    func signOut() {
        sessionToken = nil
        accountStatus = nil
        isAuthenticated = false
        deleteSessionToken()
    }

    // MARK: - Keychain

    private func saveSessionToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadSessionToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteSessionToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Wire types

    private struct AppleAuthBody: Encodable {
        let identityToken: String
        let email: String?
        let fullName: String?
    }
}

// MARK: - Account Status Model

/// 账号状态，对齐后端 `AccountStatus`。
struct AccountStatus: Codable, Hashable {
    let userId: String
    let freeCredits: Int
    let paidCredits: Int
    let totalCredits: Int
    let freeMonthlyCredits: Int
    let maxQuestionsPerReading: Int
    let subscription: SubscriptionInfo?

    struct SubscriptionInfo: Codable, Hashable {
        let productId: String
        let status: String
        let expiresAt: String?
    }

    var hasSubscription: Bool {
        subscription?.status == "active"
    }
}

/// Apple Sign In 响应，对齐后端 `AuthResponse`。
struct AuthResponse: Decodable {
    let sessionToken: String
    let account: AccountStatus
}
