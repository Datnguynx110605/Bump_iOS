import SwiftUI

@main
struct BumpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var environment = AppEnvironment(
        baseURL: AppConfig.baseURL,
        session: .shared
    )

    init() {
        // Larger disk cache so photos already seen this session don't get re-downloaded
        // on relaunch — cuts cellular/battery cost for a photo-heavy feed.
        URLCache.shared = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 300 * 1024 * 1024)
        BumpNavigationAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(environment.authSession)
                .environment(LanguagePreference.shared)
                .environment(AppearancePreference.shared)
                .tint(BumpColor.brand)
        }
    }
}
