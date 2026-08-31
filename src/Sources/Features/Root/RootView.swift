import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(AppEnvironment.self) private var environment
    @Environment(LanguagePreference.self) private var languagePreference
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
        .animation(.easeInOut(duration: 0.25), value: authSession.isAuthenticated)
        .animation(BumpMotion.standard, value: hasSeenIntro)
        .onChange(of: authSession.isAuthenticated, initial: true) { _, isAuthenticated in
            if isAuthenticated {
                environment.notificationHubClient.start()
                if NotificationPreference.isEnabled { LocalNotificationScheduler.requestAuthorizationIfNeeded() }
            } else {
                environment.notificationHubClient.stop()
            }
        }
    }
}
