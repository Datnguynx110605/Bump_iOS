import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let authSession: AuthSession
    let api: APIClient
    let notificationHubClient: NotificationHubClient
    let feedRefreshSignal = FeedRefreshSignal()
    let notificationRouteSignal = NotificationRouteSignal()
    let locationProvider = LocationProvider()

    let accountService: AccountService
    let authService: AuthService
    let emailService: EmailService
    let postService: PostService
    let commentService: CommentService
    let reactionService: ReactionService
    let followService: FollowService
    let shopService: ShopService
    let notificationService: NotificationService
    let reportService: ReportService
    let saveService: SaveService
    let reactionStore: ReactionStore
    let followStore: FollowStore
    let saveStore: SaveStore
    let shopCache: ShopCache
    let accountCache: AccountCache

    init(baseURL: URL) {
        let authSession = AuthSession(baseURL: baseURL)
        let api = APIClient(baseURL: baseURL, authSession: authSession)

        let accountService = AccountService(api: api)
        let reactionService = ReactionService(api: api)
        let followService = FollowService(api: api)
        let shopService = ShopService(api: api)
        let saveService = SaveService(api: api)

        self.authSession = authSession
        self.api = api
        self.notificationHubClient = NotificationHubClient(baseURL: baseURL, authSession: authSession)
        self.accountService = accountService
        self.authService = AuthService(api: api)
        self.emailService = EmailService(api: api)
        self.postService = PostService(api: api)
        self.commentService = CommentService(api: api)
        self.reactionService = reactionService
        self.followService = followService
        self.shopService = shopService
        self.notificationService = NotificationService(api: api)
        self.reportService = ReportService(api: api)
        self.saveService = saveService
        // Stores and caches share the service instances above rather than constructing a
        // second copy of each.
        self.reactionStore = ReactionStore(reactionService: reactionService)
        self.followStore = FollowStore(followService: followService)
        self.saveStore = SaveStore(saveService: saveService)
        self.shopCache = ShopCache(shopService: shopService)
        self.accountCache = AccountCache(accountService: accountService)

        let notificationRouteSignal = notificationRouteSignal
        self.notificationHubClient.onNotificationTapped = { [weak notificationRouteSignal] route in
            notificationRouteSignal?.open(route)
        }
    }
}

enum AppConfig {
    static let baseURL = URL(string: "https://bumpserver-production.up.railway.app")!
}
