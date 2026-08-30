import Foundation

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

    @discardableResult
    func togglePost(_ id: UUID) async -> Bool {
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
        return likedPostIds.contains(id)
    }

    @discardableResult
    func toggleComment(_ id: UUID) async -> Bool {
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
        return likedCommentIds.contains(id)
    }
}
