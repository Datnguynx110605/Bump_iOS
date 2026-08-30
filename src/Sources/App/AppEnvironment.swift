import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let authSession: AuthSession
    let api: APIClient
    let notificationHubClient: NotificationHubClient
    let feedRefreshSignal = FeedRefreshSignal()

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

        self.authSession = authSession
        self.api = api
        self.notificationHubClient = NotificationHubClient(baseURL: baseURL, authSession: authSession)
        self.accountService = AccountService(api: api)
        self.authService = AuthService(api: api)
        self.emailService = EmailService(api: api)
        self.postService = PostService(api: api)
        self.commentService = CommentService(api: api)
        self.reactionService = ReactionService(api: api)
        self.followService = FollowService(api: api)
        self.shopService = ShopService(api: api)
        self.notificationService = NotificationService(api: api)
        self.reportService = ReportService(api: api)
        self.saveService = SaveService(api: api)
        self.reactionStore = ReactionStore(reactionService: ReactionService(api: api))
        self.followStore = FollowStore(followService: FollowService(api: api))
        self.saveStore = SaveStore(saveService: SaveService(api: api))
        self.shopCache = ShopCache(shopService: ShopService(api: api))
        self.accountCache = AccountCache(accountService: AccountService(api: api))
    }
}

enum AppConfig {
    static let baseURL = URL(string: "http://192.168.1.4:5294")!
}
