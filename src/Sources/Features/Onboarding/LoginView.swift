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
        VStack(alignment: .leading, spacing: BumpSpacing.l) {
            VStack(alignment: .leading, spacing: BumpSpacing.s) {
                Text("Welcome back")
                    .font(.largeTitle.bold())
                    .foregroundStyle(BumpColor.textPrimary)
                Text("Log in to continue.")
                    .font(.subheadline)
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
                    FieldHint(text: String(localized: "Enter a valid email address."), tone: .error)
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

            Spacer()

            Button {
                Task { await login() }
            } label: {
                Text("Log In")
            }
            .buttonStyle(.bumpPrimary(isLoading: isLoading))
            .disabled(!isValid || isLoading)
        }
        .padding(.horizontal, BumpSpacing.l)
        .padding(.bottom, BumpSpacing.l)
        .background(BumpColor.surface)
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
