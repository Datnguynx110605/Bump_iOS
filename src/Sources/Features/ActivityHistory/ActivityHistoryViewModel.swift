import Foundation

@MainActor
@Observable
final class ActivityHistoryViewModel {
    var comments: [CommentSummaryDto] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    private var nextCursor: String?
    private var hasMore = true
    private let commentService: CommentService

    init(commentService: CommentService) {
        self.commentService = commentService
    }

    func loadInitialIfNeeded() async {
        guard comments.isEmpty else { return }
        await load(cursor: nil, append: false)
    }

    func reload() async {
        await load(cursor: nil, append: false)
    }

    func loadMoreIfNeeded(current: CommentSummaryDto) async {
        guard hasMore, !isLoadingMore, comments.last?.id == current.id else { return }
        await load(cursor: nextCursor, append: true)
    }

    func deleteComment(_ comment: CommentSummaryDto) async {
        do {
            try await commentService.delete(commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
        } catch {
        }
    }

    private func load(cursor: String?, append: Bool) async {
        if append { isLoadingMore = true } else { isLoading = true }
        errorMessage = nil
        defer {
            if append { isLoadingMore = false } else { isLoading = false }
        }
        do {
            let page = try await commentService.mine(cursor: cursor)
            if append { comments.append(contentsOf: page.items) } else { comments = page.items }
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
            if !append {
                errorMessage = APIError.userMessage(for: error)
            }
        }
    }
}
