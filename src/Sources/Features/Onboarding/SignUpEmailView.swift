import SwiftUI

struct SignUpEmailView: View {
    @Binding var path: [OnboardingRoute]
    @Environment(AppEnvironment.self) private var environment

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private var isValid: Bool { EmailRule.isValid(email) }

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.l) {
            VStack(alignment: .leading, spacing: BumpSpacing.s) {
                Text("What's your email?")
                    .font(.largeTitle.bold())
                Text("We'll send you a 6-digit code to confirm it's you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, BumpSpacing.l)

            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                TextField("you@example.com", text: $email)
                    .textFieldStyle(.bump)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                if !email.isEmpty && !isValid {
                    FieldHint(text: "Enter a valid email address.", tone: .error)
                }
            }

            if let errorMessage {
                InlineErrorBanner(message: errorMessage)
            }

            Spacer()

            Button {
                Task { await sendCode() }
            } label: {
                Text("Continue")
            }
            .buttonStyle(.bumpPrimary(isLoading: isLoading))
            .disabled(!isValid || isLoading)
        }
        .padding(.horizontal, BumpSpacing.l)
        .padding(.bottom, BumpSpacing.l)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isFocused = true }
    }

    private func sendCode() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await environment.emailService.sendForRegister(email: email)
            path.append(.otpVerify(email: email))
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
        }
    }
}
