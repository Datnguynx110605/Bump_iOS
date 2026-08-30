import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthSession.self) private var authSession
    @Environment(AppEnvironment.self) private var environment
    @State private var showingDeleteConfirm = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    NavigationLink("Edit Profile") { EditProfileView() }
                }

                Section("Security") {
                    NavigationLink("Change Password") { ChangePasswordView() }
                    NavigationLink("Change Email") { ChangeEmailView() }
                }

                Section("Activity") {
                    NavigationLink("Activity History") { ActivityHistoryView() }
                }

                Section {
                    Button("Log Out", role: .destructive) {
                        authSession.signOut()
                    }
                    Button("Delete Account", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                    if let deleteError {
                        InlineErrorBanner(message: deleteError)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete your account? This can't be undone from the app.",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task { await deleteAccount() }
                }
            }
        }
    }

    private func deleteAccount() async {
        do {
            try await environment.accountService.deleteAccount()
            authSession.signOut()
        } catch {
            deleteError = (error as? LocalizedError)?.errorDescription ?? "Couldn't delete your account."
        }
    }
}
