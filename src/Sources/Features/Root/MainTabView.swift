import SwiftUI

private enum MainTab: Hashable {
    case home, search, create, notifications, profile
}

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
                    showingCreatePost = true
                } else {
                    selectedTab = newValue
                }
            }
        )
    }

    var body: some View {
        TabView(selection: selectedTabBinding) {
            Tab("Home", systemImage: "house.fill", value: MainTab.home) {
                HomeView { selectedTab = .search }
            }
            Tab("Search", systemImage: "magnifyingglass", value: MainTab.search) {
                SearchView()
            }
            Tab("tab.post", systemImage: "plus.circle.fill", value: MainTab.create) {
                Color.clear
            }
            Tab("Alerts", systemImage: "bell.fill", value: MainTab.notifications) {
                NotificationsView(path: $notificationsPath)
            }
            Tab("Profile", systemImage: "person.crop.circle.fill", value: MainTab.profile) {
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
