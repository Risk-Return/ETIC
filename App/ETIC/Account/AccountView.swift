import SwiftUI
import StoreKit

/// 账号管理页：显示额度、订阅状态，支持订阅和充值。
///
/// - 一个订阅选项（月度订阅 $9.99，每月 30 次解读）
/// - 三个充值选项（20 次 $9.99 / 50 次 $19.99 / 120 次 $39.99）
/// - 每月 3 次免费额度，每次解读最多 3 个追问
struct AccountView: View {
    @StateObject private var auth = AuthService.shared
    @StateObject private var store = StoreKitService.shared

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    if let status = auth.accountStatus {
                        statusCard(status)
                        paymentLink
                        passwordLink(status)
                        signOutButton
                    } else {
                        ProgressView()
                            .padding(.top, 40)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(L10n.Account.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await auth.refreshAccountStatus()
            await store.loadProducts()
        }
    }

    // MARK: - Status card

    private func statusCard(_ status: AccountStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Account.creditsTitle)
                .font(InkTheme.serifTitle(18))
                .foregroundStyle(InkTheme.ink)

            HStack(spacing: 16) {
                creditBadge(
                    label: L10n.Account.freeCredits,
                    count: status.freeCredits,
                    total: status.freeMonthlyCredits,
                    color: InkTheme.azure
                )
                creditBadge(
                    label: L10n.Account.paidCredits,
                    count: status.paidCredits,
                    total: nil,
                    color: InkTheme.cinnabar
                )
            }

            if status.hasSubscription {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(InkTheme.cinnabar)
                    Text(L10n.Account.subscribed)
                        .font(InkTheme.serifBody(14))
                        .foregroundStyle(InkTheme.inkSoft)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(InkTheme.inkSoft.opacity(0.2), lineWidth: 1))
    }

    private func creditBadge(
        label: String, count: Int, total: Int?, color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(InkTheme.inkSoft)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(color)
                if let total {
                    Text("/ \(total)")
                        .font(.caption)
                        .foregroundStyle(InkTheme.inkSoft)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Payment link

    private var paymentLink: some View {
        NavigationLink {
            PaymentView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Account.paymentTitle)
                        .font(InkTheme.serifTitle(18))
                        .foregroundStyle(InkTheme.ink)
                    Text(L10n.Account.paymentSubtitle)
                        .font(InkTheme.serifBody(14))
                        .foregroundStyle(InkTheme.inkSoft)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(InkTheme.inkSoft)
            }
            .padding(16)
            .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(InkTheme.inkSoft.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - Password link

    private func passwordLink(_ status: AccountStatus) -> some View {
        NavigationLink {
            ChangePasswordView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text((status.hasPassword ?? false)
                         ? L10n.Account.changePassword
                         : L10n.Account.setPassword)
                        .font(InkTheme.serifTitle(18))
                        .foregroundStyle(InkTheme.ink)
                    Text(L10n.Account.passwordDesc)
                        .font(InkTheme.serifBody(14))
                        .foregroundStyle(InkTheme.inkSoft)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(InkTheme.inkSoft)
            }
            .padding(16)
            .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(InkTheme.inkSoft.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - Subscription (legacy, replaced by PaymentView)

    private func subscriptionSection(_ status: AccountStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Account.subscriptionTitle)
                .font(InkTheme.serifTitle(18))
                .foregroundStyle(InkTheme.ink)

            Text(L10n.Account.subscriptionDesc)
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.inkSoft)

            if status.hasSubscription {
                subscribedCard(status)
            } else if let product = subscriptionProduct {
                purchaseCard(
                    product: product,
                    buttonTitle: L10n.Account.subscribe,
                    isPurchasing: store.purchaseInProgress == product.id
                )
            } else {
                loadingPlaceholder
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(InkTheme.inkSoft.opacity(0.2), lineWidth: 1))
    }

    private func subscribedCard(_ status: AccountStatus) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(InkTheme.cinnabar)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Account.subscribed)
                    .font(InkTheme.serifBody(16))
                    .foregroundStyle(InkTheme.ink)
                if let expires = status.subscription?.expiresAt {
                    Text("\(L10n.Account.expiresAt): \(expires.prefix(10))")
                        .font(.caption)
                        .foregroundStyle(InkTheme.inkSoft)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(InkTheme.paper, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Top-up

    private func topUpSection(_ status: AccountStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Account.topUpTitle)
                .font(InkTheme.serifTitle(18))
                .foregroundStyle(InkTheme.ink)

            Text(L10n.Account.topUpDesc)
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.inkSoft)

            if store.products.isEmpty {
                loadingPlaceholder
            } else {
                ForEach(topUpProducts, id: \.id) { product in
                    topUpRow(product: product)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(InkTheme.inkSoft.opacity(0.2), lineWidth: 1))
    }

    private func topUpRow(product: Product) -> some View {
        let credits = StoreConfig.topUpProducts.first(where: { $0.productID == product.id })?.credits ?? 0

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(credits) \(L10n.Account.readings)")
                    .font(InkTheme.serifBody(16))
                    .foregroundStyle(InkTheme.ink)
                Text(product.displayPrice)
                    .font(.caption)
                    .foregroundStyle(InkTheme.inkSoft)
            }
            Spacer()
            Button {
                Task {
                    if await store.purchaseByProductID(product.id) {
                        await auth.refreshAccountStatus()
                    }
                }
            } label: {
                if store.purchaseInProgress == product.id {
                    ProgressView()
                        .frame(width: 20, height: 20)
                } else {
                    Text(L10n.Account.buy)
                        .font(InkTheme.serifBody(14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(InkTheme.cinnabar, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .disabled(store.purchaseInProgress != nil)
        }
        .padding(12)
        .background(InkTheme.paper, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private var subscriptionProduct: Product? {
        store.products.first(where: { $0.id == StoreConfig.subscriptionProductID })
    }

    private var topUpProducts: [Product] {
        store.products.filter { $0.id != StoreConfig.subscriptionProductID }
    }

    private func purchaseCard(
        product: Product, buttonTitle: String, isPurchasing: Bool
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(InkTheme.serifBody(16))
                    .foregroundStyle(InkTheme.ink)
                Text(product.displayPrice)
                    .font(.caption)
                    .foregroundStyle(InkTheme.inkSoft)
            }
            Spacer()
            Button {
                Task {
                    if await store.purchaseByProductID(product.id) {
                        await auth.refreshAccountStatus()
                    }
                }
            } label: {
                if isPurchasing {
                    ProgressView()
                        .frame(width: 20, height: 20)
                } else {
                    Text(buttonTitle)
                        .font(InkTheme.serifBody(14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(InkTheme.cinnabar, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .disabled(store.purchaseInProgress != nil)
        }
        .padding(12)
        .background(InkTheme.paper, in: RoundedRectangle(cornerRadius: 10))
    }

    private var loadingPlaceholder: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button(role: .destructive) {
            auth.signOut()
        } label: {
            Text(L10n.Account.signOut)
                .font(InkTheme.serifBody(15))
                .foregroundStyle(InkTheme.cinnabar)
        }
        .padding(.top, 8)
    }
}

#Preview {
    NavigationStack {
        AccountView()
    }
}
