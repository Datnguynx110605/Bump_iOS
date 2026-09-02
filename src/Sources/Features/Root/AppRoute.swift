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

// Local notification banners can only carry the two routes notifications point at
// (post, account); the userInfo payload is round-tripped through UNNotificationRequest.
extension AppRoute {
    private static let typeKey = "routeType"
    private static let idKey = "routeId"

    var notificationUserInfo: [String: String]? {
        switch self {
        case .post(let id): return [Self.typeKey: "post", Self.idKey: id.uuidString]
        case .account(let id): return [Self.typeKey: "account", Self.idKey: id.uuidString]
        default: return nil
        }
    }

    init?(notificationUserInfo userInfo: [AnyHashable: Any]) {
        guard let type = userInfo[Self.typeKey] as? String,
              let idString = userInfo[Self.idKey] as? String,
              let id = UUID(uuidString: idString) else { return nil }
        switch type {
        case "post": self = .post(id)
        case "account": self = .account(id)
        default: return nil
        }
    }
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
