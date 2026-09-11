import Foundation

enum ReactorsKind {
    case post(UUID)
    case comment(UUID)
}

@MainActor
@Observable
final class ReactorsListViewModel {
    let kind: ReactorsKind

    var reactors: [ReactionDto] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    private var nextCursor: String?
    private var hasMore = true
    private let reactionService: ReactionService

    init(kind: ReactorsKind, reactionService: ReactionService) {
        self.kind = kind
        self.reactionService = reactionService
    }

    func loadInitialIfNeeded() async {
        guard reactors.isEmpty else { return }
        await load(cursor: nil, append: false)
    }

    func reload() async {
        await load(cursor: nil, append: false)
    }

    func loadMoreIfNeeded(current: ReactionDto) async {
        guard hasMore, !isLoadingMore, reactors.isNearEnd(current) else { return }
        await load(cursor: nextCursor, append: true)
    }

    private func load(cursor: String?, append: Bool) async {
        if append { isLoadingMore = true } else { isLoading = true }
        errorMessage = nil
        defer {
            if append { isLoadingMore = false } else { isLoading = false }
        }
        do {
            let page: CursorPage<ReactionDto>
            switch kind {
            case .post(let id):
                page = try await reactionService.reactions(postId: id, cursor: cursor)
            case .comment(let id):
                page = try await reactionService.reactions(commentId: id, cursor: cursor)
            }
            if append { reactors.append(contentsOf: page.items) } else { reactors = page.items }
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
            if !append {
                errorMessage = APIError.userMessage(for: error)
            }
        }
    }
}
