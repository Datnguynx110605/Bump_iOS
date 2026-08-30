import SwiftUI

struct ChangePasswordView: View {
    @Environment(AppEnvironment.self) private var environment
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
                VStack(alignment: .leading, spacing: 4) {
                    if newPassword.isEmpty || PasswordRule.isValid(newPassword) {
                        Text("10-40 characters.")
                    } else {
                        Text("10-40 characters (currently \(newPassword.count)).")
                            .foregroundStyle(.red)
                    }
                    if !confirmPassword.isEmpty {
                        Text(newPassword == confirmPassword ? "Passwords match." : "Passwords don't match.")
                            .foregroundStyle(newPassword == confirmPassword ? .green : .red)
                    }
                }
            }
            if let errorMessage {
                InlineErrorBanner(message: errorMessage)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Change Password")
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
            Button("OK") { dismiss() }
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
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't update your password."
        }
    }
}
