import Foundation

@MainActor
@Observable
final class ProfileViewModel {
    let accountId: UUID

    var account: AccountSummaryDto?
    var posts: [PostSummaryDto] = []
    var isLoadingAccount = false
    var isLoadingPosts = false
    var isLoadingMorePosts = false
    var errorMessage: String?

    private var nextCursor: String?
    private var hasMore = true
    private let accountService: AccountService
    private let postService: PostService

    init(accountId: UUID, accountService: AccountService, postService: PostService) {
        self.accountId = accountId
        self.accountService = accountService
        self.postService = postService
    }

    func loadIfNeeded() async {
        if account == nil { await loadAccount() }
        if posts.isEmpty { await loadPosts() }
    }

    func loadAccount() async {
        isLoadingAccount = true
        errorMessage = nil
        defer { isLoadingAccount = false }
        do {
            account = try await accountService.account(id: accountId)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(localized: "Something went wrong.")
        }
    }

    func loadPosts() async {
        isLoadingPosts = true
        defer { isLoadingPosts = false }
        do {
            let page = try await postService.byAccount(accountId, cursor: nil)
            posts = page.items
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
        }
    }

    func loadMorePostsIfNeeded(current: PostSummaryDto) async {
        guard hasMore, !isLoadingMorePosts, posts.last?.id == current.id else { return }
        isLoadingMorePosts = true
        defer { isLoadingMorePosts = false }
        do {
            let page = try await postService.byAccount(accountId, cursor: nextCursor)
            posts.append(contentsOf: page.items)
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
        }
    }

    func refresh() async {
        await loadAccount()
        nextCursor = nil
        hasMore = true
        await loadPosts()
    }
}
