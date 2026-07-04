import SwiftUI
import AuthenticationServices

/// 登录页：Sign in with Apple。
///
/// 作为根视图展示，登录成功后 AuthService.isAuthenticated 变 true，
/// ETICApp 自动切换到 MainTabView。
struct LoginView: View {
    @StateObject private var auth = AuthService.shared

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

                #if DEBUG
                Button {
                    Task { await auth.testLogin() }
                } label: {
                    Text("Test Login (Dev)")
                        .font(InkTheme.serifBody(14))
                        .foregroundStyle(InkTheme.inkSoft)
                        .underline()
                }
                .padding(.top, 8)
                #endif

                Spacer().frame(height: 32)
            }
        }
    }
}

#Preview {
    LoginView()
}
