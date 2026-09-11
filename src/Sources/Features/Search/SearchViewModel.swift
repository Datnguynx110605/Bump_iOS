import Foundation

enum SearchScope: String, CaseIterable, Identifiable {
    case posts = "Posts"
    case shops = "Shops"
    case accounts = "Accounts"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .posts: String(localized: "Posts")
        case .shops: String(localized: "Shops")
        case .accounts: String(localized: "Accounts")
        }
    }
}

@MainActor
@Observable
final class SearchViewModel {
    var query = "" {
        didSet { scheduleSearch() }
    }
    var scope: SearchScope = .posts {
        didSet {
            guard oldValue != scope else { return }
            Task { await runSearch() }
        }
    }

    var posts: [PostFeedItemDto] = []
    var shops: [ShopSummaryDto] = []
    var accounts: [AccountSummaryDto] = []
    var isLoading = false
    var errorMessage: String?
    /// Guards against the `.task` on the last row firing again before the previous page
    /// lands. Without it, a page appends more than once and `ForEach` ends up with
    /// duplicate ids. Every other paginated view model in the app already has this.
    private var isLoadingMore = false

    private var postsCursor: String?
    private var postsHasMore = true
    private var shopsCursor: String?
    private var shopsHasMore = true
    private var accountsCursor: String?
    private var accountsHasMore = true

    private var searchTask: Task<Void, Never>?
    private let postService: PostService
    private let shopService: ShopService
    private let accountService: AccountService

    init(postService: PostService, shopService: ShopService, accountService: AccountService) {
        self.postService = postService
        self.shopService = shopService
        self.accountService = accountService
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearResults()
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await runSearch()
        }
    }

    private func clearResults() {
        posts = []; shops = []; accounts = []
        postsCursor = nil; shopsCursor = nil; accountsCursor = nil
        postsHasMore = true; shopsHasMore = true; accountsHasMore = true
        errorMessage = nil
    }

    func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { clearResults(); return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            switch scope {
            case .posts:
                let page = try await postService.search(keyword: trimmed, cursor: nil)
                posts = page.items; postsCursor = page.nextCursor; postsHasMore = page.hasMore
            case .shops:
                let page = try await shopService.search(keyword: trimmed, cursor: nil)
                shops = page.items; shopsCursor = page.nextCursor; shopsHasMore = page.hasMore
            case .accounts:
                let page = try await accountService.searchByKeyword(trimmed, cursor: nil)
                accounts = page.items; accountsCursor = page.nextCursor; accountsHasMore = page.hasMore
            }
        } catch {
            errorMessage = APIError.userMessage(for: error)
        }
    }

    func loadMorePostsIfNeeded(current: PostFeedItemDto) async {
        guard postsHasMore, !isLoadingMore, posts.isNearEnd(current) else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let page = try? await postService.search(keyword: trimmed, cursor: postsCursor) else { return }
        posts.append(contentsOf: page.items); postsCursor = page.nextCursor; postsHasMore = page.hasMore
    }

    func loadMoreShopsIfNeeded(current: ShopSummaryDto) async {
        guard shopsHasMore, !isLoadingMore, shops.isNearEnd(current) else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let page = try? await shopService.search(keyword: trimmed, cursor: shopsCursor) else { return }
        shops.append(contentsOf: page.items); shopsCursor = page.nextCursor; shopsHasMore = page.hasMore
    }

    func loadMoreAccountsIfNeeded(current: AccountSummaryDto) async {
        guard accountsHasMore, !isLoadingMore, accounts.isNearEnd(current) else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let page = try? await accountService.searchByKeyword(trimmed, cursor: accountsCursor) else { return }
        accounts.append(contentsOf: page.items); accountsCursor = page.nextCursor; accountsHasMore = page.hasMore
    }
}
