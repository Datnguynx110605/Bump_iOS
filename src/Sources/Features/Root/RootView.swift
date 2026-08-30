import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Group {
            if authSession.isAuthenticated {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlowView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authSession.isAuthenticated)
        .onChange(of: authSession.isAuthenticated, initial: true) { _, isAuthenticated in
            if isAuthenticated {
                environment.notificationHubClient.start()
            } else {
                environment.notificationHubClient.stop()
            }
        }
    }
}
