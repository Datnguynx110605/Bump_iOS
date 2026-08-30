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

    private var nextCursor: String?
    private var hasMore = true
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
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
        }
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
