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
    let blockService: BlockService
    let reactionStore: ReactionStore
    let followStore: FollowStore
    let saveStore: SaveStore
    let blockStore: BlockStore
    let shopCache: ShopCache
    let accountCache: AccountCache

    /// `session` exists so screenshot/demo builds can swap the transport without any
    /// service, store or view knowing. It defaults to `.shared`, so production behaviour
    /// is unchanged.
    init(baseURL: URL, session: URLSession = .shared) {
        let authSession = AuthSession(baseURL: baseURL, session: session)
        let api = APIClient(baseURL: baseURL, authSession: authSession, session: session)

        let accountService = AccountService(api: api)
        let reactionService = ReactionService(api: api)
        let followService = FollowService(api: api)
        let shopService = ShopService(api: api)
        let saveService = SaveService(api: api)
        let blockService = BlockService(api: api)

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
        self.blockService = blockService
        // Stores and caches share the service instances above rather than constructing a
        // second copy of each.
        let followStore = FollowStore(followService: followService)
        self.reactionStore = ReactionStore(reactionService: reactionService)
        self.followStore = followStore
        self.saveStore = SaveStore(saveService: saveService)
        self.blockStore = BlockStore(blockService: blockService, followStore: followStore)
        self.shopCache = ShopCache(shopService: shopService)
        self.accountCache = AccountCache(accountService: accountService)

        // Taps arrive on PushRegistration, which AppDelegate owns, so the app graph hands it
        // the pieces it cannot reach: the API surface, the session it gates uploads on, and
        // where to send a route.
        let notificationRouteSignal = notificationRouteSignal
        PushRegistration.shared.service = self.notificationService
        PushRegistration.shared.authSession = authSession
        PushRegistration.shared.onNotificationTapped = { [weak notificationRouteSignal] route in
            notificationRouteSignal?.open(route)
        }
    }
}

enum AppConfig {
    static let baseURL = URL(string: "https://bumpserver-production.up.railway.app")!
}
