import Foundation

enum FeedSort: String, CaseIterable, Identifiable {
    case latest = "Latest"
    case top = "Top"
    var id: String { rawValue }
}

@MainActor
@Observable
final class FeedViewModel {
    var posts: [PostFeedItemDto] = []
    var sort: FeedSort = .latest {
        didSet {
            guard oldValue != sort else { return }
            Task { await reload() }
        }
    }
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    var hasNewPosts = false

    private var nextCursor: String?
    private var hasMore = true
    private var topPostId: UUID?
    private let postService: PostService

    init(postService: PostService) {
        self.postService = postService
    }

    func loadInitialIfNeeded() async {
        guard posts.isEmpty else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await fetchPage(cursor: nil)
            posts = page.items
            nextCursor = page.nextCursor
            hasMore = page.hasMore
            topPostId = page.items.first?.id
            hasNewPosts = false
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
        }
    }

    /// Cheap freshness probe (single-item page) so revisiting the feed doesn't force a full
    /// reload — and idle polling doesn't cost more than a tiny request every cycle.
    func checkForNewPosts() async {
        guard sort == .latest, !isLoading else { return }
        guard let page = try? await postService.latest(cursor: nil, pageSize: 1) else { return }
        if let latestId = page.items.first?.id, latestId != topPostId {
            hasNewPosts = true
        }
    }

    func refreshIfStale() async {
        guard !posts.isEmpty else { await reload(); return }
        await checkForNewPosts()
        if hasNewPosts { await reload() }
    }

    func loadMoreIfNeeded(currentItem: PostFeedItemDto) async {
        guard hasMore, !isLoadingMore, posts.last?.id == currentItem.id else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await fetchPage(cursor: nextCursor)
            posts.append(contentsOf: page.items)
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
        }
    }

    private func fetchPage(cursor: String?) async throws -> CursorPage<PostFeedItemDto> {
        switch sort {
        case .latest: return try await postService.latest(cursor: cursor)
        case .top: return try await postService.mostReacted(cursor: cursor)
        }
    }
}
