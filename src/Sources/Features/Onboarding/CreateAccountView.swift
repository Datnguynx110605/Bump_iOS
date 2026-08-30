import SwiftUI

struct CreateAccountView: View {
    @Binding var path: [OnboardingRoute]
    let email: String
    let registrationToken: String
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSession.self) private var authSession

    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var bio = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isNameValid: Bool { AccountNameRule.isValid(name) }
    private var isPasswordValid: Bool { PasswordRule.isValid(password) }
    private var passwordsMatch: Bool { !confirmPassword.isEmpty && password == confirmPassword }
    private var isValid: Bool { isNameValid && isPasswordValid && passwordsMatch }

    private var passwordHint: String {
        guard !password.isEmpty, !isPasswordValid else { return "10-40 characters." }
        return "10-40 characters (currently \(password.count))."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BumpSpacing.l) {
                VStack(alignment: .leading, spacing: BumpSpacing.s) {
                    Text("Create your profile")
                        .font(.largeTitle.bold())
                    Text("Pick a username and password.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, BumpSpacing.l)

                VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                    TextField("username", text: $name)
                        .textFieldStyle(.bump)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: name) { _, newValue in
                            name = AccountNameRule.sanitize(newValue)
                        }
                    FieldHint(
                        text: name.isEmpty ? "Lowercase letters and numbers only, no spaces." : "Looks good.",
                        tone: name.isEmpty ? .neutral : .success)
                }

                VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.bump)
                        .textContentType(.newPassword)
                    FieldHint(text: passwordHint, tone: password.isEmpty || isPasswordValid ? .neutral : .error)
                }

                VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                    SecureField("Confirm password", text: $confirmPassword)
                        .textFieldStyle(.bump)
                        .textContentType(.newPassword)
                    if !confirmPassword.isEmpty {
                        FieldHint(
                            text: passwordsMatch ? "Passwords match." : "Passwords don't match.",
                            tone: passwordsMatch ? .success : .error)
                    }
                }

                VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                    TextField("Bio (optional)", text: $bio, axis: .vertical)
                        .textFieldStyle(.bump)
                        .lineLimit(3...6)
                    Text("\(bio.count)/2000")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    InlineErrorBanner(message: errorMessage)
                }

                Button {
                    Task { await createAccount() }
                } label: {
                    Text("Create Account")
                }
                .buttonStyle(.bumpPrimary(isLoading: isLoading))
                .disabled(!isValid || isLoading)
            }
            .padding(.horizontal, BumpSpacing.l)
            .padding(.bottom, BumpSpacing.l)
        }
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    private func createAccount() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await environment.accountService.create(
                registrationToken: registrationToken,
                name: name,
                password: password,
                bio: bio.isEmpty ? nil : bio
            )
            let tokens = try await environment.authService.login(email: email, password: password)
            authSession.setTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
        }
    }
}
