import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(AppEnvironment.self) private var environment
    @Environment(LanguagePreference.self) private var languagePreference
    @Environment(AppearancePreference.self) private var appearancePreference
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenIntroWalkthrough") private var hasSeenIntro = false
    @State private var showingSplash = true

    var body: some View {
        ZStack {
            Group {
                if !hasSeenIntro {
                    IntroWalkthroughView { hasSeenIntro = true }
                        .transition(.opacity)
                } else if authSession.isAuthenticated {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    OnboardingFlowView()
                        .transition(.opacity)
                }
            }

            if showingSplash {
                SplashView { showingSplash = false }
                    .transition(.identity)
            }
        }
        .environment(\.locale, languagePreference.locale)
        .preferredColorScheme(appearancePreference.appearance.colorScheme)
        .bumpAnimation(BumpMotion.standard, value: authSession.isAuthenticated)
        .bumpAnimation(BumpMotion.standard, value: hasSeenIntro)
        .onChange(of: authSession.isAuthenticated, initial: true) { _, isAuthenticated in
            if isAuthenticated {
                if scenePhase == .active { environment.notificationHubClient.start() }
                if NotificationPreference.isEnabled { LocalNotificationScheduler.requestAuthorizationIfNeeded() }
                Task { await environment.followStore.primeIfNeeded() }
            } else {
                environment.notificationHubClient.stop()
                environment.followStore.reset()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard authSession.isAuthenticated else { return }
            switch newPhase {
            case .active:
                environment.notificationHubClient.start()
            case .background:
                environment.notificationHubClient.stop()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
