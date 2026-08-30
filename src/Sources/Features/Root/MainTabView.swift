import SwiftUI

private enum MainTab: Hashable {
    case feed, search, create, notifications, profile
}

struct MainTabView: View {
    @Environment(AuthSession.self) private var authSession
    @State private var selectedTab: MainTab = .feed
    @State private var showingCreatePost = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Feed", systemImage: "house.fill", value: MainTab.feed) {
                FeedView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: MainTab.search) {
                SearchView()
            }
            Tab("Post", systemImage: "plus.circle.fill", value: MainTab.create) {
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
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .create {
                showingCreatePost = true
                selectedTab = .feed
            }
        }
        .sheet(isPresented: $showingCreatePost) {
            CreatePostView()
        }
    }
}
