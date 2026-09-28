import Foundation
import SwiftUI

enum AppRoute: Hashable {
    case post(UUID)
    case account(UUID)
    case shop(UUID)
    case followers(UUID)
    case following(UUID)
    case postReactors(UUID)
    case commentReactors(UUID)
    case saved
}

extension View {
    /// Installs every route this app can push.
    ///
    /// `zoomSource` opts the post route into iOS 18's zoom transition, where the tapped
    /// photo grows into the detail screen instead of sliding in from the right. Photos
    /// are what this app navigates *by*, and a push gives no clue which of the six on
    /// screen you just opened; the zoom answers that before the screen has finished
    /// arriving.
    ///
    /// Optional because the same routes are reached from places with no photo to grow
    /// from — a notification, a deep link, a search result. Where the namespace is
    /// absent, or where it carries no matching source, SwiftUI falls back to the
    /// standard push on its own.
    func appRouteDestinations(zoomSource: Namespace.ID? = nil) -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .post(let id):
                PostDetailView(postId: id)
                    .zoomTransition(from: zoomSource, id: AppRoute.post(id))
            case .account(let id):
                ProfileView(accountId: id)
            case .shop(let id):
                ShopDetailView(shopId: id)
            case .followers(let id):
                FollowListView(accountId: id, kind: .followers)
            case .following(let id):
                FollowListView(accountId: id, kind: .following)
            case .postReactors(let id):
                ReactorsListView(kind: .post(id))
            case .commentReactors(let id):
                ReactorsListView(kind: .comment(id))
            case .saved:
                SavedView()
            }
        }
    }
}

private extension View {
    /// `navigationTransition` takes a non-optional namespace, so the branch has to happen
    /// outside it rather than inside the argument.
    @ViewBuilder
    func zoomTransition(from namespace: Namespace.ID?, id: AppRoute) -> some View {
        if let namespace {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
