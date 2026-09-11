import Foundation

@MainActor
@Observable
final class SaveStore {
    private(set) var savedPostIds: Set<UUID> = []
    private(set) var savedShopIds: Set<UUID> = []
    private let saveService: SaveService

    init(saveService: SaveService) {
        self.saveService = saveService
    }

    func isSaved(post id: UUID) -> Bool { savedPostIds.contains(id) }
    func isSaved(shop id: UUID) -> Bool { savedShopIds.contains(id) }

    func setSaved(post id: UUID, _ saved: Bool) {
        if saved { savedPostIds.insert(id) } else { savedPostIds.remove(id) }
    }

    func setSaved(shop id: UUID, _ saved: Bool) {
        if saved { savedShopIds.insert(id) } else { savedShopIds.remove(id) }
    }

    /// Clears state on sign-out so the next account doesn't inherit this one's bookmarks.
    /// Saved *shops* have no per-row correction from a feed payload the way posts do, so
    /// without this they survive a sign-out intact.
    func reset() {
        savedPostIds = []
        savedShopIds = []
    }

    @discardableResult
    func togglePost(_ id: UUID) async -> Bool {
        let wasSaved = savedPostIds.contains(id)
        if wasSaved { savedPostIds.remove(id) } else { savedPostIds.insert(id) }
        do {
            if wasSaved {
                try await saveService.unsavePost(id)
            } else {
                try await saveService.savePost(id)
            }
        } catch {
            if wasSaved { savedPostIds.insert(id) } else { savedPostIds.remove(id) }
        }
        return savedPostIds.contains(id)
    }

    @discardableResult
    func toggleShop(_ id: UUID) async -> Bool {
        let wasSaved = savedShopIds.contains(id)
        if wasSaved { savedShopIds.remove(id) } else { savedShopIds.insert(id) }
        do {
            if wasSaved {
                try await saveService.unsaveShop(id)
            } else {
                try await saveService.saveShop(id)
            }
        } catch {
            if wasSaved { savedShopIds.insert(id) } else { savedShopIds.remove(id) }
        }
        return savedShopIds.contains(id)
    }
}
