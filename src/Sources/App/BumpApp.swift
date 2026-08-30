import SwiftUI

@main
struct BumpApp: App {
    @State private var environment = AppEnvironment(baseURL: AppConfig.baseURL)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(environment.authSession)
                .tint(Color.accentColor)
        }
    }
}
