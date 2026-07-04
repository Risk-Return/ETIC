import Foundation

/// StoreKit 商品 ID 与后端计费配置。
///
/// **需要你填写**：将以下 product ID 与 App Store Connect 中配置的保持一致。
/// 后端 `.env` 中的 `ETIC_SUBSCRIPTION_PRODUCT_ID` 和 `ETIC_TOPUP_PRODUCTS` 也需匹配。
enum StoreConfig {

    // MARK: - Subscription

    /// 月度订阅商品 ID。
    static let subscriptionProductID = "ai.etic.app.subscription.monthly"

    // MARK: - Top-up (Credit Packs)

    /// 充值商品列表（商品 ID → 额度数）。
    /// 三个选项：5 次、10 次、25 次。
    static let topUpProducts: [(productID: String, credits: Int, displayKey: String)] = [
        ("ai.etic.app.credits.5",  5,  "topup.5"),
        ("ai.etic.app.credits.10", 10, "topup.10"),
        ("ai.etic.app.credits.25", 25, "topup.25"),
    ]

    /// 所有需要从 App Store 拉取的商品 ID。
    static var allProductIDs: Set<String> {
        var ids: Set<String> = [subscriptionProductID]
        ids.formUnion(topUpProducts.map { $0.productID })
        return ids
    }
}
