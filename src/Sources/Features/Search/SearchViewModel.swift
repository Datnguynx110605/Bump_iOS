import Foundation

enum SearchScope: String, CaseIterable, Identifiable {
    case posts = "Posts"
    case shops = "Shops"
    case accounts = "Accounts"
    var id: String { rawValue }
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
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
        }
    }

    func loadMorePostsIfNeeded(current: PostFeedItemDto) async {
        guard postsHasMore, posts.last?.id == current.id else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let page = try? await postService.search(keyword: trimmed, cursor: postsCursor) else { return }
        posts.append(contentsOf: page.items); postsCursor = page.nextCursor; postsHasMore = page.hasMore
    }

    func loadMoreShopsIfNeeded(current: ShopSummaryDto) async {
        guard shopsHasMore, shops.last?.id == current.id else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let page = try? await shopService.search(keyword: trimmed, cursor: shopsCursor) else { return }
        shops.append(contentsOf: page.items); shopsCursor = page.nextCursor; shopsHasMore = page.hasMore
    }

    func loadMoreAccountsIfNeeded(current: AccountSummaryDto) async {
        guard accountsHasMore, accounts.last?.id == current.id else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let page = try? await accountService.searchByKeyword(trimmed, cursor: accountsCursor) else { return }
        accounts.append(contentsOf: page.items); accountsCursor = page.nextCursor; accountsHasMore = page.hasMore
    }
}
