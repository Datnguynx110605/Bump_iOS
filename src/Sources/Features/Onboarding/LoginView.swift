import SwiftUI

struct LoginView: View {
    @Binding var path: [OnboardingRoute]
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSession.self) private var authSession

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValid: Bool { EmailRule.isValid(email) && !password.isEmpty }

    var body: some View {
        AuthFormLayout {
            VStack(alignment: .leading, spacing: BumpSpacing.s) {
                Text("Welcome back")
                    .font(BumpFont.display)
                    .foregroundStyle(BumpColor.textPrimary)
                Text("Good to see you again.")
                    .font(BumpFont.callout)
                    .foregroundStyle(BumpColor.textSecondary)
            }
            .padding(.top, BumpSpacing.l)

            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                TextField("Email", text: $email)
                    .textFieldStyle(.bump)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !email.isEmpty && !EmailRule.isValid(email) {
                    FieldHint(text: "Enter a valid email address.", tone: .error)
                }
            }

            SecureField("Password", text: $password)
                .textFieldStyle(.bump)
                .textContentType(.password)
                .onSubmit { Task { await login() } }

            HStack {
                Button("Forgot password?") {
                    path.append(.recoveryEmail(purpose: .forgotPassword))
                }
                .buttonStyle(.bumpText)
                Spacer()
                Button("Recover account") {
                    path.append(.recoveryEmail(purpose: .recoverAccount))
                }
                .buttonStyle(.bumpText)
            }

            if let errorMessage {
                InlineErrorBanner(message: errorMessage)
            }
        } action: {
            Button {
                Task { await login() }
            } label: {
                Text("Log in")
            }
            .buttonStyle(.bumpPrimary(isLoading: isLoading))
            .disabled(!isValid || isLoading)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func login() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let tokens = try await environment.authService.login(email: email, password: password)
            authSession.setTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        } catch {
            errorMessage = APIError.userMessage(for: error)
        }
    }
}
