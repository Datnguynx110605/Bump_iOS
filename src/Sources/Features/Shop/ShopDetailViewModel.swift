import Foundation

@MainActor
@Observable
final class ShopDetailViewModel {
    let shopId: UUID

    var shop: ShopDto?
    var isSaved = false
    var posts: [PostSummaryDto] = []
    var isLoadingShop = false
    var isLoadingPosts = false
    var isLoadingMorePosts = false
    var errorMessage: String?

    private var nextCursor: String?
    private var hasMore = true
    private let shopService: ShopService
    private let postService: PostService

    init(shopId: UUID, shopService: ShopService, postService: PostService) {
        self.shopId = shopId
        self.shopService = shopService
        self.postService = postService
    }

    func loadIfNeeded() async {
        if shop == nil { await loadShop() }
        if posts.isEmpty { await loadPosts() }
    }

    func refresh() async {
        await loadShop()
        nextCursor = nil
        hasMore = true
        await loadPosts()
    }

    func loadShop() async {
        isLoadingShop = true
        errorMessage = nil
        defer { isLoadingShop = false }
        do {
            let detail = try await shopService.shop(id: shopId)
            shop = detail.shop
            isSaved = detail.isSaved
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(localized: "Something went wrong.")
        }
    }

    func loadPosts() async {
        isLoadingPosts = true
        defer { isLoadingPosts = false }
        do {
            let page = try await postService.byShop(shopId, cursor: nil)
            posts = page.items
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
        }
    }

    func loadMorePostsIfNeeded(current: PostSummaryDto) async {
        guard hasMore, !isLoadingMorePosts, posts.last?.id == current.id else { return }
        isLoadingMorePosts = true
        defer { isLoadingMorePosts = false }
        do {
            let page = try await postService.byShop(shopId, cursor: nextCursor)
            posts.append(contentsOf: page.items)
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
        }
    }
}
