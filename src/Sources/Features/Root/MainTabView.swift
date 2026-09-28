import SwiftUI

private enum MainTab: Hashable {
    case home, search, create, notifications, profile
}

/// The five-tab shell.
///
/// Every tab glyph is the **outline** member of the Bump icon family, at one weight.
/// Selection is carried by the brand tint and the heavier label weight set in
/// `BumpNavigationAppearance`, not by swapping in a filled glyph — a bar whose selected
/// item changes shape as well as colour reads as two icon families sharing a bar.
///
/// These go through `templateImage` rather than `BumpIcon`. `TabView` bridges to
/// `UITabBarItem`, which takes a `UIImage`; a SwiftUI `Canvas` handed to it renders
/// nothing at all.
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
            Tab(value: MainTab.home) {
                HomeView { selectedTab = .search }
            } label: {
                tabLabel("Home", .home)
            }
            Tab(value: MainTab.search) {
                SearchView()
            } label: {
                tabLabel("Search", .search)
            }
            Tab(value: MainTab.create) {
                Color.clear
            } label: {
                tabLabel("tab.post", .plus, variant: .circled)
            }
            Tab(value: MainTab.notifications) {
                NotificationsView(path: $notificationsPath)
            } label: {
                tabLabel("Alerts", .bell)
            }
            Tab(value: MainTab.profile) {
                if let accountId = authSession.accountId {
                    NavigationStack {
                        ProfileView(accountId: accountId)
                            .appRouteDestinations()
                    }
                }
            } label: {
                tabLabel("Profile", .person)
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

    /// The tab bar renders at a fixed 26pt: `UITabBar` sizes its own items and does not
    /// take part in Dynamic Type for the glyph, so scaling here would only produce a
    /// blurrier raster at the same drawn size.
    private func tabLabel(_ title: LocalizedStringKey, _ glyph: BumpGlyph, variant: BumpGlyphVariant = .outline) -> some View {
        Label {
            Text(title)
        } icon: {
            if let image = glyph.templateImage(size: 26, variant: variant) {
                Image(uiImage: image)
            }
        }
    }
}
