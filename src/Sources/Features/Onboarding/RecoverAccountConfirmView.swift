import SwiftUI

struct RecoverAccountConfirmView: View {
    @Binding var path: [OnboardingRoute]
    let email: String
    let registrationToken: String
    @Environment(AppEnvironment.self) private var environment

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.l) {
            VStack(alignment: .leading, spacing: BumpSpacing.s) {
                Text("Recover your account")
                    .font(.largeTitle.bold())
                Text("We found a deleted account for \(email). Recovering it will restore your profile and data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, BumpSpacing.l)

            if let errorMessage {
                InlineErrorBanner(message: errorMessage)
            }

            Spacer()

            Button {
                Task { await recover() }
            } label: {
                Text("Recover Account")
            }
            .buttonStyle(.bumpPrimary(isLoading: isLoading))
            .disabled(isLoading)
        }
        .padding(.horizontal, BumpSpacing.l)
        .padding(.bottom, BumpSpacing.l)
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
