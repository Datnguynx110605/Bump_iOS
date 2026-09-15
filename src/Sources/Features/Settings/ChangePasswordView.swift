import SwiftUI

struct ChangePasswordView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSession.self) private var authSession
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSave = false

    private var isValid: Bool {
        !currentPassword.isEmpty && PasswordRule.isValid(newPassword) && newPassword == confirmPassword
    }

    var body: some View {
        Form {
            Section {
                SecureField("Current password", text: $currentPassword)
                    .textContentType(.password)
            }
            Section {
                SecureField("New password", text: $newPassword)
                    .textContentType(.newPassword)
                SecureField("Confirm new password", text: $confirmPassword)
                    .textContentType(.newPassword)
            } footer: {
                // Both hints go through `FieldHint`. The match hint used raw `.green` /
                // `.red` — system `.green` measures about 1.4:1 on a light card, and the
                // tone rested on color alone. The length hint was already on a semantic
                // token but still color-only, and mixing a bare `Text` with a `FieldHint`
                // in one footer reads as two different components. `ResetPasswordView`,
                // the onboarding twin of this screen, has used `FieldHint` for both all
                // along; this brings the pair in line with it.
                VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                    FieldHint(
                        text: newPassword.isEmpty || PasswordRule.isValid(newPassword)
                            ? "10-40 characters."
                            : "10-40 characters (currently \(newPassword.count)).",
                        tone: newPassword.isEmpty || PasswordRule.isValid(newPassword) ? .neutral : .error
                    )
                    if !confirmPassword.isEmpty {
                        FieldHint(
                            text: newPassword == confirmPassword
                                ? "Passwords match."
                                : "Passwords don't match.",
                            tone: newPassword == confirmPassword ? .success : .error
                        )
                    }
                }
            }
            if let errorMessage {
                InlineErrorBanner(message: errorMessage)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BumpColor.surface)
        .navigationTitle("Change password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving { ProgressView() } else { Text("Save") }
                }
                .disabled(!isValid || isSaving)
            }
        }
        .alert("Password Updated", isPresented: $didSave) {
            Button("OK") {
                dismiss()
                authSession.signOut()
            }
        } message: {
            Text("Please log in again with your new password.")
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await environment.accountService.changePassword(current: currentPassword, new: newPassword)
            didSave = true
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't update your password."))
        }
    }
}
