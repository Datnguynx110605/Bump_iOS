import SwiftUI

@main
struct BumpApp: App {
    @State private var environment = AppEnvironment(
        baseURL: AppConfig.baseURL,
        session: BumpApp.session
    )

    /// `.shared` in every normal run. Demo mode — used only to capture App Store
    /// screenshots — swaps in a session that answers from fixtures and cannot reach the
    /// network. See `DemoMode`.
    private static var session: URLSession {
        #if DEBUG
        if DemoMode.isEnabled { return DemoMode.makeSession() }
        #endif
        return .shared
    }

    init() {
        // Larger disk cache so photos already seen this session don't get re-downloaded
        // on relaunch — cuts cellular/battery cost for a photo-heavy feed.
        URLCache.shared = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 300 * 1024 * 1024)
        BumpNavigationAppearance.configure()

        #if DEBUG
        if DemoMode.isEnabled {
            // Skip the one-time intro so a freshly installed demo build lands on the feed,
            // and pre-answer the notification prompt so it can't appear over a capture.
            UserDefaults.standard.set(true, forKey: "hasSeenIntroWalkthrough")
            UserDefaults.standard.set(false, forKey: NotificationPreference.key)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    #if DEBUG
                    // Puts the app in its signed-in state without a round trip. The token
                    // carries the claims `AuthSession` reads; nothing verifies a signature.
                    if DemoMode.isEnabled, !environment.authSession.isAuthenticated {
                        environment.authSession.setTokens(
                            accessToken: DemoMode.accessToken,
                            refreshToken: "demo-refresh"
                        )
                    }
                    #endif
                }
                .environment(environment)
                .environment(environment.authSession)
                .environment(LanguagePreference.shared)
                .environment(AppearancePreference.shared)
                .tint(BumpColor.brand)
        }
    }
}
