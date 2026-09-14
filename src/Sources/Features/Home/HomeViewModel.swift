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
    /// Newest post the screen has shown. The freshness probe compares against it, so a
    /// reload only happens when the feed genuinely changed.
    private var topPostId: UUID?

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

    /// The two halves are guarded independently on purpose. Sharing one `posts.isEmpty`
    /// guard meant a nearby load cancelled by a tab switch — which leaves `nearby` on
    /// `.loading` — could never be retried, because the next visit returned early on the
    /// posts it had already fetched. The section spun a spinner for the life of the app.
    func loadInitialIfNeeded() async {
        if posts.isEmpty { await reload() }
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
            topPostId = page.items.first?.id
        } catch {
            errorMessage = APIError.userMessage(for: error)
        }
    }

    /// Pull-to-refresh refreshes both halves of the screen, but a nearby section the user
    /// has never granted permission for stays as the priming card rather than prompting.
    func refreshAll() async {
        await reload()
        if nearby != .needsPermission { await loadNearby() }
    }

    /// The automatic path, run on every revisit, foreground and tick.
    ///
    /// One single-item request answers "is the top of the feed still the same post?", and
    /// only a different answer costs a full reload. That keeps an idle screen close to
    /// free and, more importantly, keeps a scrolled list from jumping every minute for
    /// content that has not changed.
    ///
    /// The nearby strip stays out of this on purpose: refreshing it means a fresh GPS fix,
    /// and the top-rated shops within five kilometres do not change often enough to pay
    /// for one every minute. Pull-to-refresh still updates it.
    func refreshIfStale() async {
        guard !isLoading else { return }
        // An empty feed here means the first load was cancelled or failed — the tab switch
        // that cancelled it is exactly the case this screen used to get stuck on.
        guard !posts.isEmpty else {
            await reload()
            return
        }
        guard let page = try? await postService.related(cursor: nil, pageSize: 1) else { return }
        if page.items.first?.id != topPostId { await reload() }
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
            // Leaving a tab mid-load cancels the request; that is not a failed lookup and
            // must not replace the carousel with an error card.
            if !error.isCancellation { nearby = .failed }
        }
    }

    func loadMoreIfNeeded(currentItem: PostFeedItemDto) async {
        guard hasMore, !isLoadingMore, posts.isNearEnd(currentItem) else { return }
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
