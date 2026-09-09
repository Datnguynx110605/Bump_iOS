import SwiftUI

struct ResetPasswordView: View {
    @Binding var path: [OnboardingRoute]
    let email: String
    let registrationToken: String
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSession.self) private var authSession

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isPasswordValid: Bool { PasswordRule.isValid(newPassword) }
    private var passwordsMatch: Bool { !confirmPassword.isEmpty && newPassword == confirmPassword }
    private var isValid: Bool { isPasswordValid && passwordsMatch }

    private var passwordHint: String {
        guard !newPassword.isEmpty, !isPasswordValid else { return String(localized: "10-40 characters.") }
        return String(localized: "10-40 characters (currently \(newPassword.count)).")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.l) {
            VStack(alignment: .leading, spacing: BumpSpacing.s) {
                Text("Set a new password")
                    .font(.largeTitle.bold())
                Text("Choose a new password for \(email).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, BumpSpacing.l)

            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                SecureField("New password", text: $newPassword)
                    .textFieldStyle(.bump)
                    .textContentType(.newPassword)
                FieldHint(text: passwordHint, tone: newPassword.isEmpty || isPasswordValid ? .neutral : .error)
            }

            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                SecureField("Confirm password", text: $confirmPassword)
                    .textFieldStyle(.bump)
                    .textContentType(.newPassword)
                if !confirmPassword.isEmpty {
                    FieldHint(
                        text: passwordsMatch ? String(localized: "Passwords match.") : String(localized: "Passwords don't match."),
                        tone: passwordsMatch ? .success : .error)
                }
            }

            if let errorMessage {
                InlineErrorBanner(message: errorMessage)
            }

            Spacer()

            Button {
                Task { await resetPassword() }
            } label: {
                Text("Reset Password")
            }
            .buttonStyle(.bumpPrimary(isLoading: isLoading))
            .disabled(!isValid || isLoading)
        }
        .padding(.horizontal, BumpSpacing.l)
        .padding(.bottom, BumpSpacing.l)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resetPassword() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await environment.accountService.resetPassword(registrationToken: registrationToken, newPassword: newPassword)
            let tokens = try await environment.authService.login(email: email, password: newPassword)
            authSession.setTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        } catch {
            errorMessage = APIError.userMessage(for: error)
        }
    }
}
