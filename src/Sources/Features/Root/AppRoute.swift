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
    func appRouteDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .post(let id):
                PostDetailView(postId: id)
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
