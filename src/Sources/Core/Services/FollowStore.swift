import Foundation

@MainActor
@Observable
final class FollowStore {
    private(set) var followingIds: Set<UUID> = []
    private let followService: FollowService

    init(followService: FollowService) {
        self.followService = followService
    }

    func isFollowing(_ accountId: UUID) -> Bool { followingIds.contains(accountId) }

    @discardableResult
    func toggle(_ accountId: UUID) async -> Bool {
        let wasFollowing = followingIds.contains(accountId)
        if wasFollowing { followingIds.remove(accountId) } else { followingIds.insert(accountId) }
        do {
            if wasFollowing {
                try await followService.unfollow(accountId)
            } else {
                try await followService.follow(accountId)
            }
        } catch {
            if wasFollowing { followingIds.insert(accountId) } else { followingIds.remove(accountId) }
        }
        return followingIds.contains(accountId)
    }
}
