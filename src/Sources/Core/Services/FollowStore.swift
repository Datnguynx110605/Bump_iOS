import Foundation

@MainActor
@Observable
final class FollowStore {
    private(set) var followingIds: Set<UUID> = []
    private let followService: FollowService

    init(followService: FollowService) {
        self.followService = followService
    }

    private var hasPrimed = false

    func isFollowing(_ accountId: UUID) -> Bool { followingIds.contains(accountId) }

    /// Seeds the set of accounts the signed-in user follows, so opening the profile of
    /// someone they already follow shows "Following" rather than "Follow".
    ///
    /// `AccountSummaryDto` carries no `isFollowing` flag and there's no "am I following
    /// X" endpoint, so knowing the whole set is the only way to answer the question
    /// client-side.
    ///
    /// ponytail: capped at `maxPrimePages` pages; a user following more than
    /// `maxPrimePages * 100` accounts can still see a stale "Follow" on the overflow.
    /// The real fix is an `isFollowing` field on the account payload — then this whole
    /// method goes away.
    func primeIfNeeded() async {
        guard !hasPrimed else { return }
        hasPrimed = true
        var cursor: String?
        for _ in 0..<Self.maxPrimePages {
            guard let page = try? await followService.myFollowing(cursor: cursor, pageSize: 100) else { return }
            followingIds.formUnion(page.items.map(\.accountId))
            guard page.hasMore, let next = page.nextCursor else { return }
            cursor = next
        }
    }

    /// Drops a follow the app knows the server has already severed — blocking cuts the
    /// edge in both directions, and no unfollow request is sent for it.
    func forget(_ accountId: UUID) {
        followingIds.remove(accountId)
    }

    /// Clears state on sign-out so the next account doesn't inherit this one's follows.
    func reset() {
        followingIds = []
        hasPrimed = false
    }

    private static let maxPrimePages = 5

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
