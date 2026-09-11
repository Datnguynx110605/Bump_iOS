import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthSession.self) private var authSession
    @Environment(AppEnvironment.self) private var environment
    @Environment(LanguagePreference.self) private var languagePreference
    @Environment(AppearancePreference.self) private var appearancePreference
    @State private var showingDeleteConfirm = false
    @State private var showingLogOutConfirm = false
    @State private var deleteError: String?
    @AppStorage(NotificationPreference.key) private var notificationsEnabled = true

    var body: some View {
        @Bindable var languagePreference = languagePreference
        @Bindable var appearancePreference = appearancePreference
        NavigationStack {
            Form {
                Section("Profile") {
                    NavigationLink { EditProfileView() } label: {
                        Label("Edit Profile", systemImage: "person.crop.circle")
                    }
                }

                Section("Security") {
                    NavigationLink { ChangePasswordView() } label: {
                        Label("Change Password", systemImage: "lock")
                    }
                    NavigationLink { ChangeEmailView() } label: {
                        Label("Change Email", systemImage: "envelope")
                    }
                }

                Section("Privacy") {
                    NavigationLink { BlockedAccountsView() } label: {
                        Label("Blocked Accounts", systemImage: "hand.raised")
                    }
                }

                Section("Activity") {
                    NavigationLink { ActivityHistoryView() } label: {
                        Label("Activity History", systemImage: "clock.arrow.circlepath")
                    }
                }

                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, isOn in
                            if isOn { LocalNotificationScheduler.requestAuthorizationIfNeeded() }
                        }
                }

                Section("Language") {
                    Picker("Language", selection: $languagePreference.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $appearancePreference.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.displayName).tag(appearance)
                        }
                    }
                }

                Section {
                    Button("Log Out", role: .destructive) {
                        showingLogOutConfirm = true
                    }
                    Button("Delete Account", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                    if let deleteError {
                        InlineErrorBanner(message: deleteError)
                    }
                }
            }
            .bumpScrollBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Log out of Bump?",
                isPresented: $showingLogOutConfirm,
                titleVisibility: .visible
            ) {
                Button("Log Out", role: .destructive) {
                    authSession.signOut()
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
            deleteError = APIError.userMessage(for: error, fallback: String(localized: "Couldn't delete your account."))
        }
    }
}
