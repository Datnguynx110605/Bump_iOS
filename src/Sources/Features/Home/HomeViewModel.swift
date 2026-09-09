import Foundation

@MainActor
@Observable
final class HomeViewModel {
    /// Nearby shops fail in two distinguishable ways and the screen says which: the
    /// endpoint takes two non-optional coordinates, so without permission it cannot be
    /// called at all. Collapsing that into an empty list would tell the user there are no
    /// good shops nearby, which is not what happened.
    enum NearbyState: Equatable {
        case needsPermission
        case loading
        case locationOff
        case failed
        case loaded([ShopSummaryDto])
    }

    var posts: [PostFeedItemDto] = []
    var nearby: NearbyState
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    private var nextCursor: String?
    private var hasMore = true

    private let postService: PostService
    private let shopService: ShopService
    private let locationProvider: LocationProvider

    init(postService: PostService, shopService: ShopService, locationProvider: LocationProvider) {
        self.postService = postService
        self.shopService = shopService
        self.locationProvider = locationProvider
        // Asking for location the instant the app opens, with nothing on screen to
        // explain why, is the reliable way to get it denied permanently. When the system
        // has never asked, the screen shows a card that explains the trade first and only
        // prompts on tap; when permission already exists, the section just loads.
        self.nearby = locationProvider.isDenied ? .locationOff
            : locationProvider.canRequest ? .needsPermission
            : .loading
    }

    func loadInitialIfNeeded() async {
        guard posts.isEmpty else { return }
        await reload()
        if nearby == .loading { await loadNearby() }
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await postService.related(cursor: nil)
            posts = page.items
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(localized: "Something went wrong.")
        }
    }

    /// Pull-to-refresh refreshes both halves of the screen, but a nearby section the user
    /// has never granted permission for stays as the priming card rather than prompting.
    func refreshAll() async {
        await reload()
        if nearby != .needsPermission { await loadNearby() }
    }

    func loadNearby() async {
        nearby = .loading
        guard let coordinate = await locationProvider.requestCurrent() else {
            // Still undetermined means the prompt was dismissed without an answer, so the
            // section offers it again rather than claiming something failed.
            nearby = locationProvider.isDenied ? .locationOff
                : locationProvider.canRequest ? .needsPermission
                : .failed
            return
        }
        do {
            let page = try await shopService.bestAround(coordinate)
            nearby = .loaded(page.items)
        } catch {
            nearby = .failed
        }
    }

    func loadMoreIfNeeded(currentItem: PostFeedItemDto) async {
        guard hasMore, !isLoadingMore, posts.last?.id == currentItem.id else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await postService.related(cursor: nextCursor)
            posts.append(contentsOf: page.items)
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
            // A failed page-in leaves the loaded feed alone; the next scroll retries.
        }
    }
}
