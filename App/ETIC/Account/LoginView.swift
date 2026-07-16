import SwiftUI
import AuthenticationServices

/// 登录页：Sign in with Apple + 邮箱验证码登录。
///
/// 作为根视图展示，登录成功后 AuthService.isAuthenticated 变 true，
/// ETICApp 自动切换到 MainTabView。
struct LoginView: View {
    @StateObject private var auth = AuthService.shared

    private enum EmailLoginMode {
        case code, password
    }

    @State private var mode: EmailLoginMode = .code
    @State private var email = ""
    @State private var code = ""
    @State private var password = ""
    @State private var codeSent = false
    @State private var isSendingCode = false
    @State private var isVerifying = false
    @State private var resendCountdown = 0

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 48)

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

                    Spacer().frame(height: 12)

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

                    orDivider

                    emailSection

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
        }
    }

    // MARK: - Email sign in

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(InkTheme.inkSoft.opacity(0.3))
                .frame(height: 1)
            Text(L10n.Account.emailLoginTitle)
                .font(InkTheme.serifBody(13))
                .foregroundStyle(InkTheme.inkSoft)
                .fixedSize()
            Rectangle()
                .fill(InkTheme.inkSoft.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, 24)
    }

    private var emailSection: some View {
        VStack(spacing: 12) {
            Picker("", selection: $mode) {
                Text(L10n.Account.codeLogin).tag(EmailLoginMode.code)
                Text(L10n.Account.passwordLogin).tag(EmailLoginMode.password)
            }
            .pickerStyle(.segmented)

            TextField(L10n.Account.emailPlaceholder, text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(InkTheme.serifBody(16))
                .padding(14)
                .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(InkTheme.inkSoft.opacity(0.2), lineWidth: 1))

            if mode == .password {
                passwordFields
            } else if codeSent {
                HStack(spacing: 12) {
                    TextField(L10n.Account.codePlaceholder, text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(InkTheme.serifBody(16))
                        .padding(14)
                        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(InkTheme.inkSoft.opacity(0.2), lineWidth: 1))

                    Button {
                        Task { await sendCode() }
                    } label: {
                        if isSendingCode {
                            ProgressView()
                        } else if resendCountdown > 0 {
                            Text("\(L10n.Account.resend) (\(resendCountdown)s)")
                                .font(InkTheme.serifBody(13))
                        } else {
                            Text(L10n.Account.resend)
                                .font(InkTheme.serifBody(13))
                        }
                    }
                    .foregroundStyle(resendCountdown > 0 ? InkTheme.inkSoft : InkTheme.azure)
                    .disabled(resendCountdown > 0 || isSendingCode)
                    .fixedSize()
                }

                Text(L10n.Account.codeSent)
                    .font(InkTheme.serifBody(12))
                    .foregroundStyle(InkTheme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task { await verifyCode() }
                } label: {
                    Group {
                        if isVerifying {
                            ProgressView().tint(.white)
                        } else {
                            Text(L10n.Account.signIn)
                                .font(InkTheme.serifBody(16))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(InkTheme.cinnabar, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || isVerifying)
            } else {
                Button {
                    Task { await sendCode() }
                } label: {
                    Group {
                        if isSendingCode {
                            ProgressView().tint(.white)
                        } else {
                            Text(L10n.Account.sendCode)
                                .font(InkTheme.serifBody(16))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isEmailValid ? InkTheme.cinnabar : InkTheme.inkSoft,
                                in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isEmailValid || isSendingCode)
            }
        }
        .padding(.horizontal, 24)
    }

    private var passwordFields: some View {
        VStack(spacing: 12) {
            SecureField(L10n.Account.passwordPlaceholder, text: $password)
                .textContentType(.password)
                .font(InkTheme.serifBody(16))
                .padding(14)
                .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(InkTheme.inkSoft.opacity(0.2), lineWidth: 1))

            Button {
                Task { await signInWithPassword() }
            } label: {
                Group {
                    if isVerifying {
                        ProgressView().tint(.white)
                    } else {
                        Text(L10n.Account.signIn)
                            .font(InkTheme.serifBody(16))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    (isEmailValid && !password.isEmpty) ? InkTheme.cinnabar : InkTheme.inkSoft,
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .disabled(!isEmailValid || password.isEmpty || isVerifying)

            Text(L10n.Account.passwordLoginHint)
                .font(InkTheme.serifBody(12))
                .foregroundStyle(InkTheme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 5
    }

    private func sendCode() async {
        isSendingCode = true
        defer { isSendingCode = false }
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        if let cooldown = await auth.requestEmailCode(email: trimmed) {
            codeSent = true
            code = ""
            startCountdown(cooldown)
        }
    }

    private func verifyCode() async {
        isVerifying = true
        defer { isVerifying = false }
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let trimmedCode = code.trimmingCharacters(in: .whitespaces)
        _ = await auth.signInWithEmail(email: trimmedEmail, code: trimmedCode)
    }

    private func signInWithPassword() async {
        isVerifying = true
        defer { isVerifying = false }
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        _ = await auth.signInWithPassword(email: trimmedEmail, password: password)
    }

    private func startCountdown(_ seconds: Int) {
        resendCountdown = seconds
        Task {
            while resendCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                resendCountdown -= 1
            }
        }
    }
}

#Preview {
    LoginView()
}
