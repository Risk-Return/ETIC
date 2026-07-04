import SwiftUI
import AuthenticationServices

/// 登录页：Sign in with Apple。
///
/// 仅支持 Apple Sign In。登录成功后自动 dismiss，上层页面刷新账号状态。
struct LoginView: View {
    @StateObject private var auth = AuthService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 56))
                        .foregroundStyle(InkTheme.cinnabar)

                    Text(L10n.Account.loginTitle)
                        .font(InkTheme.serifTitle(22))
                        .foregroundStyle(InkTheme.ink)

                    Text(L10n.Account.loginDesc)
                        .font(InkTheme.serifBody(15))
                        .foregroundStyle(InkTheme.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        Task { await auth.handleAppleSignIn(result: result) }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .padding(.horizontal, 24)
                .cornerRadius(12)

                if let error = auth.errorMessage {
                    Text(error)
                        .font(InkTheme.serifBody(13))
                        .foregroundStyle(InkTheme.cinnabar)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }

                Spacer().frame(height: 32)
            }
        }
        .navigationTitle(L10n.Account.loginNavTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: auth.isAuthenticated) { _, isAuth in
            if isAuth { dismiss() }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
}
