import Foundation
import SwiftUI

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

    /// The same three labels as catalogue *keys*. `displayName` resolves eagerly against
    /// the process locale, so it cannot follow the in-app language switch; a key handed to
    /// SwiftUI resolves late, against `\.locale`.
    var titleKey: LocalizedStringKey {
        switch self {
        case .posts: "Posts"
        case .shops: "Shops"
        case .accounts: "Accounts"
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
            // Goes through the same cancellable slot as typing, without the debounce: a
            // scope tap is one discrete event, not a burst. Running it as a detached
            // `Task` left the last keystroke's pending task alive, so it woke 350ms later
            // and re-ran the identical search — two requests against a limit of twenty a
            // minute, and whichever landed second overwrote the other's results.
            scheduleSearch(debounced: false)
        }
    }

    var posts: [PostFeedItemDto] = []
    var shops: [ShopSummaryDto] = []
    var accounts: [AccountSummaryDto] = []
    var isLoading = false
    var errorMessage: String?

    /// The shop directory shown in the Shops scope before a keyword is typed. Kept apart
    /// from `shops` so switching to Shops, searching, then clearing the field restores the
    /// directory instead of leaving the last result set behind.
    var directory: [ShopSummaryDto] = []
    var isLoadingDirectory = false
    /// Non-nil only for a genuine failure. Without it a failed load rendered "No shops
    /// yet", which tells the user the app has no shops when the request simply failed —
    /// the same distinction `HomeViewModel.NearbyState` draws between `.failed` and an
    /// empty result.
    var directoryError: String?
    private var directoryCursor: String?
    private var directoryHasMore = true
    /// Separate from `isLoadingMore`: the directory and the Shops search results can both
    /// be live in this view model, and a shared flag lets one refuse the other's page.
    private var isLoadingMoreDirectory = false
    private var hasLoadedDirectory = false
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

    /// The one place a search is started. Every entry point — typing, a scope tap, the
    /// error state's retry — routes through here so there is a single in-flight task to
    /// cancel; anything that starts its own detached `Task` can neither be cancelled nor
    /// cancel what is already pending.
    ///
    /// `debounced` is false for the discrete taps, which should act immediately but must
    /// still clear whatever the last keystroke scheduled.
    private func scheduleSearch(debounced: Bool = true) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearResults()
            return
        }
        searchTask = Task {
            if debounced {
                try? await Task.sleep(for: .milliseconds(350))
            }
            guard !Task.isCancelled else { return }
            await runSearch()
        }
    }

    /// Retry behind the error state. Named rather than letting the view call `runSearch`
    /// directly, so a retry cannot start an untracked request either.
    func retrySearch() {
        scheduleSearch(debounced: false)
    }

    private func clearResults() {
        posts = []; shops = []; accounts = []
        postsCursor = nil; shopsCursor = nil; accountsCursor = nil
        postsHasMore = true; shopsHasMore = true; accountsHasMore = true
        errorMessage = nil
    }

    /// Loads the first page of the shop directory, once. Safe to call from `.task` on
    /// every appearance of the Shops scope.
    func loadDirectoryIfNeeded() async {
        guard !hasLoadedDirectory else { return }
        await loadDirectory()
    }

    /// The retry behind the directory's error state, which has to bypass the once-only
    /// guard that `loadDirectoryIfNeeded` honours.
    func retryDirectory() async {
        await loadDirectory()
    }

    private func loadDirectory() async {
        hasLoadedDirectory = true
        isLoadingDirectory = true
        directoryError = nil
        defer { isLoadingDirectory = false }
        do {
            let page = try await shopService.all(cursor: nil)
            directory = page.items
            directoryCursor = page.nextCursor
            directoryHasMore = page.hasMore
        } catch {
            // Release the guard so the next appearance tries again rather than pinning an
            // empty directory for the life of the screen. `userMessage(for:)` is nil for a
            // cancelled request, so leaving a tab mid-load retries silently instead of
            // painting an error over a healthy server.
            hasLoadedDirectory = false
            directoryError = APIError.userMessage(for: error)
        }
    }

    func loadMoreDirectoryIfNeeded(current: ShopSummaryDto) async {
        guard directoryHasMore, !isLoadingMoreDirectory, directory.isNearEnd(current) else { return }
        isLoadingMoreDirectory = true
        defer { isLoadingMoreDirectory = false }
        guard let page = try? await shopService.all(cursor: directoryCursor) else { return }
        directory.append(contentsOf: page.items)
        directoryCursor = page.nextCursor
        directoryHasMore = page.hasMore
    }

    private func runSearch() async {
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
