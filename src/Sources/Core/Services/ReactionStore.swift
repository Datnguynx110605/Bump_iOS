import Foundation

/// Result of a like toggle. `countDelta` is 0 when the request failed and the optimistic
/// change was rolled back — callers move their displayed counter by this, never by
/// assuming the tap succeeded. Reading the returned `isLiked` alone is what previously
/// let a failed like *decrement* the count it was supposed to increment.
struct ReactionToggleResult {
    let isLiked: Bool
    let countDelta: Int
}

@MainActor
@Observable
final class ReactionStore {
    private(set) var likedPostIds: Set<UUID> = []
    private(set) var likedCommentIds: Set<UUID> = []
    private let reactionService: ReactionService

    init(reactionService: ReactionService) {
        self.reactionService = reactionService
    }

    func isLiked(post id: UUID) -> Bool { likedPostIds.contains(id) }
    func isLiked(comment id: UUID) -> Bool { likedCommentIds.contains(id) }

    func setLiked(post id: UUID, _ liked: Bool) {
        if liked { likedPostIds.insert(id) } else { likedPostIds.remove(id) }
    }

    func setLiked(comment id: UUID, _ liked: Bool) {
        if liked { likedCommentIds.insert(id) } else { likedCommentIds.remove(id) }
    }

    /// Clears state on sign-out so the next account doesn't inherit this one's likes.
    func reset() {
        likedPostIds = []
        likedCommentIds = []
    }

    @discardableResult
    func togglePost(_ id: UUID) async -> ReactionToggleResult {
        let wasLiked = likedPostIds.contains(id)
        if wasLiked { likedPostIds.remove(id) } else { likedPostIds.insert(id) }
        do {
            if wasLiked {
                try await reactionService.unreact(postId: id)
            } else {
                try await reactionService.react(postId: id)
            }
        } catch {
            if wasLiked { likedPostIds.insert(id) } else { likedPostIds.remove(id) }
        }
        return result(isLiked: likedPostIds.contains(id), wasLiked: wasLiked)
    }

    @discardableResult
    func toggleComment(_ id: UUID) async -> ReactionToggleResult {
        let wasLiked = likedCommentIds.contains(id)
        if wasLiked { likedCommentIds.remove(id) } else { likedCommentIds.insert(id) }
        do {
            if wasLiked {
                try await reactionService.unreact(commentId: id)
            } else {
                try await reactionService.react(commentId: id)
            }
        } catch {
            if wasLiked { likedCommentIds.insert(id) } else { likedCommentIds.remove(id) }
        }
        return result(isLiked: likedCommentIds.contains(id), wasLiked: wasLiked)
    }

    private func result(isLiked: Bool, wasLiked: Bool) -> ReactionToggleResult {
        ReactionToggleResult(isLiked: isLiked, countDelta: isLiked == wasLiked ? 0 : (isLiked ? 1 : -1))
    }
}
