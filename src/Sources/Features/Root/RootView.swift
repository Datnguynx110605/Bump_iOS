import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("hasSeenIntroWalkthrough") private var hasSeenIntro = false

    var body: some View {
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
        .animation(.easeInOut(duration: 0.25), value: authSession.isAuthenticated)
        .animation(BumpMotion.standard, value: hasSeenIntro)
        .onChange(of: authSession.isAuthenticated, initial: true) { _, isAuthenticated in
            if isAuthenticated {
                environment.notificationHubClient.start()
            } else {
                environment.notificationHubClient.stop()
            }
        }
    }
}
