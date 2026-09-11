import Foundation

/// The set of accounts the signed-in user has blocked, held client-side.
///
/// Two reasons it can't be answered per-request. The block endpoints are queued and
/// answer `202`, so the server's own hiding only starts once the consumer has run —
/// until then a blocked author's posts are still in every cached page the app already
/// holds. And no account payload carries an `isBlocked` flag, so "have I blocked this
/// person?" has no endpoint of its own. Knowing the whole set answers both.
@MainActor
@Observable
final class BlockStore {
    private(set) var blockedIds: Set<UUID> = []

    private let blockService: BlockService
    /// Blocking severs follows in both directions server-side, so the follow set has to
    /// be corrected here or the profile shows "Following" against a server that disagrees.
    private let followStore: FollowStore
    private var hasPrimed = false

    init(blockService: BlockService, followStore: FollowStore) {
        self.blockService = blockService
        self.followStore = followStore
    }

    func isBlocked(_ accountId: UUID) -> Bool { blockedIds.contains(accountId) }

    /// Drops items authored by a blocked account.
    ///
    /// The early return is the point: almost every viewer has blocked nobody, and a
    /// plain `filter` still walks and copies the whole page for them. This is called
    /// from view bodies, so the common case has to cost nothing.
    func visible<T>(_ items: [T], author: (T) -> UUID) -> [T] {
        guard !blockedIds.isEmpty else { return items }
        return items.filter { !blockedIds.contains(author($0)) }
    }

    /// ponytail: capped at `maxPrimePages` pages, matching `FollowStore`. The server's own
    /// hiding set caps at 300 too, so the overflow is invisible either way.
    func primeIfNeeded() async {
        guard !hasPrimed else { return }
        hasPrimed = true
        var cursor: String?
        for _ in 0..<Self.maxPrimePages {
            guard let page = try? await blockService.mine(cursor: cursor, pageSize: 100) else { return }
            blockedIds.formUnion(page.items.map(\.accountId))
            guard page.hasMore, let next = page.nextCursor else { return }
            cursor = next
        }
    }

    func reset() {
        blockedIds = []
        hasPrimed = false
    }

    private static let maxPrimePages = 5

    /// Returns true when the account ended up blocked.
    @discardableResult
    func block(_ accountId: UUID) async -> Bool {
        blockedIds.insert(accountId)
        do {
            try await blockService.block(accountId)
            followStore.forget(accountId)
            return true
        } catch {
            blockedIds.remove(accountId)
            return false
        }
    }

    @discardableResult
    func unblock(_ accountId: UUID) async -> Bool {
        blockedIds.remove(accountId)
        do {
            try await blockService.unblock(accountId)
            return true
        } catch {
            blockedIds.insert(accountId)
            return false
        }
    }
}
