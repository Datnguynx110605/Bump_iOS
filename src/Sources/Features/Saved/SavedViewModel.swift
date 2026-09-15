import Foundation
import SwiftUI

enum SavedTab: String, CaseIterable {
    case posts = "Posts"
    case shops = "Shops"

    var displayName: String {
        switch self {
        case .posts: String(localized: "Posts")
        case .shops: String(localized: "Shops")
        }
    }

    /// The same labels as catalogue keys — see `SearchScope.titleKey` for why both exist.
    var titleKey: LocalizedStringKey {
        switch self {
        case .posts: "Posts"
        case .shops: "Shops"
        }
    }
}

@MainActor
@Observable
final class SavedViewModel {
    var tab: SavedTab = .posts

    var posts: [PostSummaryDto] = []
    var shops: [ShopSummaryDto] = []
    var isLoadingPosts = false
    var isLoadingShops = false
    var isLoadingMorePosts = false
    var isLoadingMoreShops = false
    var errorMessage: String?

    private var nextPostsCursor: String?
    private var hasMorePosts = true
    private var nextShopsCursor: String?
    private var hasMoreShops = true

    private let saveService: SaveService
    private let saveStore: SaveStore

    init(saveService: SaveService, saveStore: SaveStore) {
        self.saveService = saveService
        self.saveStore = saveStore
    }

    func loadIfNeeded() async {
        if posts.isEmpty { await loadPosts() }
        if shops.isEmpty { await loadShops() }
    }

    func refresh() async {
        nextPostsCursor = nil
        hasMorePosts = true
        nextShopsCursor = nil
        hasMoreShops = true
        await loadPosts()
        await loadShops()
    }

    func loadPosts() async {
        isLoadingPosts = true
        errorMessage = nil
        defer { isLoadingPosts = false }
        do {
            let page = try await saveService.myPosts(cursor: nil)
            posts = page.items
            nextPostsCursor = page.nextCursor
            hasMorePosts = page.hasMore
            for post in page.items { saveStore.setSaved(post: post.id, true) }
        } catch {
            errorMessage = APIError.userMessage(for: error)
        }
    }

    func loadMorePostsIfNeeded(current: PostSummaryDto) async {
        guard hasMorePosts, !isLoadingMorePosts, posts.isNearEnd(current) else { return }
        isLoadingMorePosts = true
        defer { isLoadingMorePosts = false }
        do {
            let page = try await saveService.myPosts(cursor: nextPostsCursor)
            posts.append(contentsOf: page.items)
            nextPostsCursor = page.nextCursor
            hasMorePosts = page.hasMore
            for post in page.items { saveStore.setSaved(post: post.id, true) }
        } catch {
        }
    }

    func loadShops() async {
        isLoadingShops = true
        errorMessage = nil
        defer { isLoadingShops = false }
        do {
            let page = try await saveService.myShops(cursor: nil)
            shops = page.items
            nextShopsCursor = page.nextCursor
            hasMoreShops = page.hasMore
            for shop in page.items { saveStore.setSaved(shop: shop.id, true) }
        } catch {
            errorMessage = APIError.userMessage(for: error)
        }
    }

    func loadMoreShopsIfNeeded(current: ShopSummaryDto) async {
        guard hasMoreShops, !isLoadingMoreShops, shops.isNearEnd(current) else { return }
        isLoadingMoreShops = true
        defer { isLoadingMoreShops = false }
        do {
            let page = try await saveService.myShops(cursor: nextShopsCursor)
            shops.append(contentsOf: page.items)
            nextShopsCursor = page.nextCursor
            hasMoreShops = page.hasMore
            for shop in page.items { saveStore.setSaved(shop: shop.id, true) }
        } catch {
        }
    }

    func removeSavedShop(_ id: UUID) {
        shops.removeAll { $0.id == id }
    }
}
