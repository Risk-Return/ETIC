import Foundation

/// StoreKit 商品 ID 与后端计费配置。
///
/// **需要你填写**：将以下 product ID 与 App Store Connect 中配置的保持一致。
/// 后端 `.env` 中的 `ETIC_SUBSCRIPTION_PRODUCT_ID` 和 `ETIC_TOPUP_PRODUCTS` 也需匹配。
enum StoreConfig {

    // MARK: - Subscription

    /// 月度订阅商品 ID。
    static let subscriptionProductID = "BuaGua_monthly_subscribe_01"

    // MARK: - Top-up (Credit Packs)

    /// 充值商品列表（商品 ID → 额度数）。
    /// 三个选项：20 次（$9.99）、50 次（$19.99）、120 次（$39.99）。
    static let topUpProducts: [(productID: String, credits: Int, displayKey: String)] = [
        ("BuaGua0001",          20,  "topup.5"),
        ("app.credits.19.99",   50,  "topup.10"),
        ("app.credits.39.99",   120, "topup.25"),
    ]

    // MARK: - Static display prices (must match App Store Connect)

    /// 订阅价格（静态展示，需与 App Store Connect 一致）。
    static let subscriptionPrice = "$9.99"

    /// 充值包价格映射（product ID → 静态价格字符串）。
    private static let priceMap: [String: String] = [
        "BuaGua0001":        "$9.99",
        "app.credits.19.99": "$19.99",
        "app.credits.39.99": "$39.99",
    ]

    /// 根据 product ID 获取静态价格字符串。
    static func priceString(for productID: String) -> String {
        priceMap[productID] ?? ""
    }

    /// 所有需要从 App Store 拉取的商品 ID。
    static var allProductIDs: Set<String> {
        var ids: Set<String> = [subscriptionProductID]
        ids.formUnion(topUpProducts.map { $0.productID })
        return ids
    }
}
