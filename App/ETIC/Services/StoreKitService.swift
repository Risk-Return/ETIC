import Foundation
import StoreKit

/// StoreKit 2 购买服务：加载商品、购买、交易验证。
///
/// 购买完成后将 `Transaction.jwsRepresentation` 提交后端 `/v1/iap/verify`，
/// 后端记录交易并发放额度/激活订阅。
@MainActor
final class StoreKitService: ObservableObject {

    static let shared = StoreKitService()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var purchaseInProgress: String?

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load products

    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            let storeProducts = try await Product.products(for: StoreConfig.allProductIDs)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Purchase

    /// Purchase a product by ID. Returns true on success.
    func purchase(productID: String) async -> Bool {
        guard let product = products.first(where: { $0.id == productID }) else {
            errorMessage = "Product not found."
            return false
        }

        purchaseInProgress = productID
        defer { purchaseInProgress = nil }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await verifyWithBackend(transaction: transaction)
                await transaction.finish()
                return true

            case .userCancelled:
                return false

            case .pending:
                errorMessage = "Purchase pending approval."
                return false

            @unknown default:
                errorMessage = "Unknown purchase result."
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Transaction listener

    /// Listen for transactions that happen outside the app (renewals, family sharing, etc.).
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await self.verifyWithBackend(transaction: transaction)
                    await transaction.finish()
                } catch {
                    // Transaction verification failed.
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreError.unverified
        }
    }

    // MARK: - Backend verification

    /// Submit transaction JWS to backend for credit/subscription activation.
    private func verifyWithBackend(transaction: Transaction) async {
        guard let header = AuthService.shared.authHeader else { return }

        let body = IAPVerifyBody(
            jwsRepresentation: transaction.jsonRepresentation.base64EncodedString(),
            productId: transaction.productID,
            originalTransactionId: String(transaction.originalID)
        )

        do {
            let data = try JSONEncoder().encode(body)
            var request = URLRequest(url: AuthService.shared.baseURL.appendingPathComponent("/v1/iap/verify"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(header, forHTTPHeaderField: "Authorization")
            request.httpBody = data

            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                await AuthService.shared.refreshAccountStatus()
            }
        } catch {
            // Silent — transaction is already finished on device.
        }
    }

    // MARK: - Errors

    enum StoreError: LocalizedError {
        case unverified

        var errorDescription: String? {
            switch self {
            case .unverified: return "Transaction could not be verified."
            }
        }
    }

    // MARK: - Wire types

    private struct IAPVerifyBody: Encodable {
        let jwsRepresentation: String
        let productId: String
        let originalTransactionId: String?
    }
}
