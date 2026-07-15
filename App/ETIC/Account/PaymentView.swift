import SwiftUI
import StoreKit

/// 付费页面：静态展示订阅套餐与充值包，供 App Store 审核截图与用户购买。
///
/// - 订阅：$9.99/月，每月 30 次卦象解读
/// - 充值包：$9.99/20 次、$19.99/50 次、$39.99/120 次
/// - 页面信息全部静态展示（来自 StoreConfig），不依赖 StoreKit 加载
/// - 点击"订阅"或"购买"按钮后，通过 product ID 调用 StoreKit 完成支付
/// - 包含"恢复购买"按钮（App Store 审核必需）
struct PaymentView: View {
    @StateObject private var auth = AuthService.shared
    @StateObject private var store = StoreKitService.shared

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(L10n.Account.paymentTitle)
                            .font(InkTheme.serifTitle(24))
                            .foregroundStyle(InkTheme.ink)
                        Text(L10n.Account.paymentSubtitle)
                            .font(InkTheme.serifBody(14))
                            .foregroundStyle(InkTheme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // Subscription section
                    subscriptionCard

                    // Top-up section
                    topUpSection

                    // Restore + legal
                    footerSection
                }
                .padding(20)
            }
        }
        .navigationTitle(L10n.Account.paymentTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subscription card

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundStyle(InkTheme.cinnabar)
                Text(L10n.Account.subscriptionTitle)
                    .font(InkTheme.serifTitle(20))
                    .foregroundStyle(InkTheme.ink)
            }

            if let status = auth.accountStatus, status.hasSubscription {
                // Already subscribed
                subscribedState(status)
            } else {
                // Static subscription card — info from StoreConfig, not StoreKit
                subscriptionStaticCard
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(InkTheme.cinnabar.opacity(0.3), lineWidth: 1.5))
    }

    private func subscribedState(_ status: AccountStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(InkTheme.cinnabar)
                Text(L10n.Account.subscribed)
                    .font(InkTheme.serifBody(18))
                    .foregroundStyle(InkTheme.ink)
            }
            if let expires = status.subscription?.expiresAt {
                Text("\(L10n.Account.expiresAt): \(expires.prefix(10))")
                    .font(InkTheme.serifBody(14))
                    .foregroundStyle(InkTheme.inkSoft)
            }
            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                    Text(L10n.Account.manageSubscription)
                }
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.azure)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InkTheme.paper, in: RoundedRectangle(cornerRadius: 12))
    }

    private var subscriptionStaticCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Price (static, matches App Store Connect)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(StoreConfig.subscriptionPrice)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(InkTheme.cinnabar)
                Text(L10n.Account.subscriptionPerMonth)
                    .font(InkTheme.serifBody(16))
                    .foregroundStyle(InkTheme.inkSoft)
            }

            // Feature list
            VStack(alignment: .leading, spacing: 10) {
                featureRow(text: L10n.Account.subscriptionFeature1)
                featureRow(text: L10n.Account.subscriptionFeature2)
                featureRow(text: L10n.Account.subscriptionFeature3)
            }

            // Subscribe button — triggers StoreKit on tap
            purchaseButton(
                productID: StoreConfig.subscriptionProductID,
                title: L10n.Account.subscribe,
                isPrimary: true
            )
        }
    }

    private func featureRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(InkTheme.cinnabar)
            Text(text)
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Top-up section

    private var topUpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(InkTheme.azure)
                Text(L10n.Account.topUpTitle)
                    .font(InkTheme.serifTitle(20))
                    .foregroundStyle(InkTheme.ink)
            }

            Text(L10n.Account.topUpDesc)
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.inkSoft)

            // Static cards from StoreConfig — no StoreKit dependency for display
            VStack(spacing: 12) {
                ForEach(StoreConfig.topUpProducts, id: \.productID) { item in
                    topUpStaticCard(item: item)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(InkTheme.inkSoft.opacity(0.2), lineWidth: 1))
    }

    private func topUpStaticCard(item: (productID: String, credits: Int, displayKey: String)) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(item.credits) \(L10n.Account.readings)")
                        .font(InkTheme.serifBody(18))
                        .foregroundStyle(InkTheme.ink)
                    HStack(spacing: 4) {
                        Text(StoreConfig.priceString(for: item.productID))
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(InkTheme.cinnabar)
                        Text(L10n.Account.topUpOneTime)
                            .font(.caption)
                            .foregroundStyle(InkTheme.inkSoft)
                    }
                }
                Spacer()
                purchaseButton(
                    productID: item.productID,
                    title: L10n.Account.buy,
                    isPrimary: false
                )
            }
        }
        .padding(16)
        .background(InkTheme.paper, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 16) {
            // Restore purchases
            Button {
                Task { await store.restorePurchases() }
            } label: {
                Text(L10n.Account.restorePurchases)
                    .font(InkTheme.serifBody(15))
                    .foregroundStyle(InkTheme.azure)
            }

            // Error message
            if let error = store.errorMessage {
                Text(error)
                    .font(InkTheme.serifBody(13))
                    .foregroundStyle(InkTheme.cinnabar)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Legal links
            HStack(spacing: 24) {
                Link(L10n.Account.termsOfService, destination: URL(string: "https://deepwitai.cn/etic/terms")!)
                    .font(.caption)
                    .foregroundStyle(InkTheme.inkSoft)
                Link(L10n.Account.privacyPolicy, destination: URL(string: "https://deepwitai.cn/etic/privacy")!)
                    .font(.caption)
                    .foregroundStyle(InkTheme.inkSoft)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Shared components

    private func purchaseButton(
        productID: String, title: String, isPrimary: Bool
    ) -> some View {
        Button {
            Task {
                if await store.purchaseByProductID(productID) {
                    await auth.refreshAccountStatus()
                }
            }
        } label: {
            if store.purchaseInProgress == productID {
                ProgressView()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.white)
            } else {
                Text(title)
                    .font(InkTheme.serifBody(16))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
        }
        .background(
            isPrimary ? InkTheme.cinnabar : InkTheme.ink,
            in: RoundedRectangle(cornerRadius: 10)
        )
        .disabled(store.purchaseInProgress != nil)
        .frame(minWidth: 100)
    }

}

#Preview {
    NavigationStack {
        PaymentView()
    }
}
