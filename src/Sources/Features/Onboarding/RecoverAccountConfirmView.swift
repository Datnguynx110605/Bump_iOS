import SwiftUI

struct RecoverAccountConfirmView: View {
    @Binding var path: [OnboardingRoute]
    let email: String
    let registrationToken: String
    @Environment(AppEnvironment.self) private var environment

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        AuthFormLayout {
            VStack(alignment: .leading, spacing: BumpSpacing.s) {
                Text("Recover your account")
                    .font(BumpFont.display)
                Text("We found a deleted account for \(email). Recovering it will restore your profile and data.")
                    .font(BumpFont.callout)
                    .foregroundStyle(BumpColor.textSecondary)
            }
            .padding(.top, BumpSpacing.l)

            if let errorMessage {
                InlineErrorBanner(message: errorMessage)
            }
        } action: {
            Button {
                Task { await recover() }
            } label: {
                Text("Recover account")
            }
            .buttonStyle(.bumpPrimary(isLoading: isLoading))
            .disabled(isLoading)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func recover() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await environment.accountService.recoverAccount(registrationToken: registrationToken)
            path = [.login]
        } catch {
            errorMessage = APIError.userMessage(for: error)
        }
    }
}
