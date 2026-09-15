import SwiftUI

private enum MainTab: Hashable {
    case home, search, create, notifications, profile
}

/// The five-tab shell.
///
/// Every tab glyph is the **outline** member of its SF Symbols family. The set used to
/// mix filled (`house.fill`, `bell.fill`) with outline (`magnifyingglass`), which reads as
/// two icon families sharing a bar. Selection is carried by the brand tint and the heavier
/// label weight set in `BumpNavigationAppearance` instead, so the glyphs stay one
/// consistent stroke weight across all five.
struct MainTabView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(AppEnvironment.self) private var environment
    @State private var selectedTab: MainTab = .home
    @State private var showingCreatePost = false
    @State private var notificationsPath = NavigationPath()

    private var selectedTabBinding: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .create {
                    HapticFeedback.selected()
                    showingCreatePost = true
                } else {
                    selectedTab = newValue
                }
            }
        )
    }

    var body: some View {
        TabView(selection: selectedTabBinding) {
            Tab("Home", systemImage: "house", value: MainTab.home) {
                HomeView { selectedTab = .search }
            }
            Tab("Search", systemImage: "magnifyingglass", value: MainTab.search) {
                SearchView()
            }
            Tab("tab.post", systemImage: "plus.circle", value: MainTab.create) {
                Color.clear
            }
            Tab("Alerts", systemImage: "bell", value: MainTab.notifications) {
                NotificationsView(path: $notificationsPath)
            }
            Tab("Profile", systemImage: "person", value: MainTab.profile) {
                if let accountId = authSession.accountId {
                    NavigationStack {
                        ProfileView(accountId: accountId)
                            .appRouteDestinations()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreatePost) {
            CreatePostView()
        }
        .onChange(of: environment.notificationRouteSignal.pendingRoute, initial: true) { _, route in
            guard let route else { return }
            selectedTab = .notifications
            notificationsPath = NavigationPath([route])
            environment.notificationRouteSignal.clear()
        }
    }
}
