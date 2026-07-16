import SwiftUI

/// 设置/修改密码页：新密码 + 确认，经会话令牌调用后端 `/v1/account/password`。
///
/// 验证码登录与密码登录获得的会话均可在此设置密码；
/// 忘记密码时先用验证码登录，再来此处重设。
struct ChangePasswordView: View {
    @StateObject private var auth = AuthService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var message: String?
    @State private var isSuccess = false

    private var hasPassword: Bool {
        auth.accountStatus?.hasPassword ?? false
    }

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Text(L10n.Account.passwordDesc)
                        .font(InkTheme.serifBody(14))
                        .foregroundStyle(InkTheme.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    SecureField(L10n.Account.newPasswordPlaceholder, text: $newPassword)
                        .textContentType(.newPassword)
                        .font(InkTheme.serifBody(16))
                        .padding(14)
                        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(InkTheme.inkSoft.opacity(0.2), lineWidth: 1))

                    SecureField(L10n.Account.confirmPasswordPlaceholder, text: $confirmPassword)
                        .textContentType(.newPassword)
                        .font(InkTheme.serifBody(16))
                        .padding(14)
                        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(InkTheme.inkSoft.opacity(0.2), lineWidth: 1))

                    Button {
                        Task { await save() }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text(hasPassword
                                     ? L10n.Account.changePassword
                                     : L10n.Account.setPassword)
                                    .font(InkTheme.serifBody(16))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canSave ? InkTheme.cinnabar : InkTheme.inkSoft,
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canSave || isSaving)

                    if let message {
                        Text(message)
                            .font(InkTheme.serifBody(13))
                            .foregroundStyle(isSuccess ? InkTheme.azure : InkTheme.cinnabar)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(hasPassword ? L10n.Account.changePassword : L10n.Account.setPassword)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSave: Bool {
        newPassword.count >= 8 && !confirmPassword.isEmpty
    }

    private func save() async {
        message = nil
        guard newPassword == confirmPassword else {
            isSuccess = false
            message = L10n.Account.passwordMismatch
            return
        }
        guard newPassword.count >= 8 && newPassword.count <= 128 else {
            isSuccess = false
            message = L10n.Account.passwordTooShort
            return
        }

        isSaving = true
        defer { isSaving = false }
        if await auth.setPassword(newPassword) {
            isSuccess = true
            message = L10n.Account.passwordSetSuccess
            newPassword = ""
            confirmPassword = ""
        } else {
            isSuccess = false
            message = L10n.Account.passwordSetFailed
        }
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
    }
}
