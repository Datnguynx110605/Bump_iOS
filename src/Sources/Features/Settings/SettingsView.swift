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
                Section {
                    NavigationLink { EditProfileView() } label: {
                        Label("Edit profile", systemImage: "person")
                    }
                } header: {
                    Text("You").bumpSectionLabel()
                }

                Section {
                    NavigationLink { ChangePasswordView() } label: {
                        Label("Change password", systemImage: "lock")
                    }
                    NavigationLink { ChangeEmailView() } label: {
                        Label("Change email", systemImage: "envelope")
                    }
                    NavigationLink { BlockedAccountsView() } label: {
                        Label("Blocked accounts", systemImage: "hand.raised")
                    }
                    NavigationLink { ActivityHistoryView() } label: {
                        Label("Activity history", systemImage: "clock.arrow.circlepath")
                    }
                } header: {
                    Text("Account & privacy").bumpSectionLabel()
                }

                Section {
                    Toggle("Push notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, isOn in
                            if isOn { LocalNotificationScheduler.requestAuthorizationIfNeeded() }
                        }
                    Picker("Language", selection: $languagePreference.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.titleKey).tag(language)
                        }
                    }
                    Picker("Appearance", selection: $appearancePreference.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.titleKey).tag(appearance)
                        }
                    }
                } header: {
                    Text("Preferences").bumpSectionLabel()
                }

                Section {
                    Button("Log out", role: .destructive) {
                        showingLogOutConfirm = true
                    }
                    Button("Delete account", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                    if let deleteError {
                        InlineErrorBanner(message: deleteError)
                    }
                }
            }
            // Grouped rows sit on the tonal step above the page. Flat: the system's
            // inset-grouped style would draw its own rounded, shadowed plates, which is
            // the floating-card idiom this design language replaced.
            .listRowBackground(BumpColor.surfaceSecondary)
            .bumpScrollBackground()
            .tint(BumpColor.brand)
            // `RootView` sets the app-wide colour scheme, but a sheet captures the trait
            // at presentation time and does not re-evaluate it. Settings is the one screen
            // that can *change* the appearance, so without this the user flips to Light
            // and watches the page behind the sheet turn while the sheet they are looking
            // at stays dark until it is dismissed and reopened.
            .preferredColorScheme(appearancePreference.appearance.colorScheme)
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
                Button("Log out", role: .destructive) {
                    authSession.signOut()
                }
            }
            .confirmationDialog(
                "Delete your account? This can't be undone from the app.",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete account", role: .destructive) {
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
