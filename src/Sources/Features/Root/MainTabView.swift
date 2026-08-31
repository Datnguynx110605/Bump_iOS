import SwiftUI

private enum MainTab: Hashable {
    case feed, search, create, notifications, profile
}

struct MainTabView: View {
    @Environment(AuthSession.self) private var authSession
    @State private var selectedTab: MainTab = .feed
    @State private var showingCreatePost = false

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
            Tab("Feed", systemImage: "house.fill", value: MainTab.feed) {
                FeedView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: MainTab.search) {
                SearchView()
            }
            Tab("tab.post", systemImage: "plus.circle.fill", value: MainTab.create) {
                Color.clear
            }
            Tab("Alerts", systemImage: "bell.fill", value: MainTab.notifications) {
                NotificationsView()
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
    }
}
