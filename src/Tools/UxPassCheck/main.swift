// Checks the branching logic added by the UI/UX pass. Three pieces earn a check; the
// rest of the pass is markup, tokens and accessibility modifiers, which a typecheck
// already covers and a runtime assertion cannot reach.
//
//  1. `HomeViewModel.loadInitialIfNeeded()` — the nearby section and the feed used to
//     share one `posts.isEmpty` guard. A nearby load cancelled by a tab switch leaves
//     `nearby` on `.loading`, and the shared guard meant the next visit returned early
//     on the posts it already had, so the section spun a spinner forever. Pinned here as
//     a state machine because the failure is invisible until you leave and come back.
//  2. `CreatePostViewModel.hasUnsavedWork` — decides whether Cancel and the dismissal
//     swipe throw work away silently. Whitespace must not count as work, or every empty
//     compose screen would demand a confirmation to close.
//  3. `PostImageCarousel`'s adjustable action — the non-swipe path VoiceOver drives.
//     Both ends have to clamp; an out-of-range `scrollPosition(id:)` scrolls nowhere and
//     strands the user mid-carousel.
//
//   cd Bump_iOS/src
//   swiftc -o /tmp/uxpasscheck Tools/UxPassCheck/*.swift && /tmp/uxpasscheck

import Foundation

// MARK: - 1. Nearby retries after a cancelled first load

/// The two guards from `HomeViewModel.loadInitialIfNeeded()`, isolated from the network.
enum NearbyState { case loading, loaded, failed }

final class FeedLoadModel {
    var postCount = 0
    var nearby: NearbyState = .loading
    private(set) var reloads = 0
    private(set) var nearbyLoads = 0

    /// Stands in for a `loadNearby()` whose request was cancelled — `HomeViewModel`
    /// deliberately leaves `.loading` in place on cancellation rather than claiming a
    /// failure, which is exactly what made the old guard sticky.
    var nearbyWillBeCancelled = false

    func loadInitialIfNeeded() {
        if postCount == 0 { reload() }
        if nearby == .loading { loadNearby() }
    }

    private func reload() { reloads += 1; postCount = 10 }

    private func loadNearby() {
        nearbyLoads += 1
        nearby = nearbyWillBeCancelled ? .loading : .loaded
    }
}

let feed = FeedLoadModel()

// First visit: the feed loads, and the nearby request is cancelled by a tab switch.
feed.nearbyWillBeCancelled = true
feed.loadInitialIfNeeded()
assert(feed.reloads == 1, "the first visit has to load the feed")
assert(feed.nearbyLoads == 1, "the first visit has to attempt nearby")
assert(feed.nearby == .loading, "a cancelled nearby load stays pending, not failed")

// Second visit. This is the regression: the old `guard posts.isEmpty else { return }`
// returned here and nearby stayed on its spinner for the life of the app.
feed.nearbyWillBeCancelled = false
feed.loadInitialIfNeeded()
assert(feed.reloads == 1, "a loaded feed must not reload on every revisit")
assert(feed.nearbyLoads == 2, "a pending nearby section has to retry on the next visit")
assert(feed.nearby == .loaded, "the retry resolves the section")

// Third visit: nothing left to do, and neither half spends a request.
feed.loadInitialIfNeeded()
assert(feed.reloads == 1 && feed.nearbyLoads == 2, "a settled screen costs nothing")

// MARK: - 2. Discard confirmation fires on real work only

func hasUnsavedWork(images: [Data], shopName: String, shopAddress: String, caption: String) -> Bool {
    !images.isEmpty
        || !shopName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !shopAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

let photo = Data([0xFF, 0xD8])
assert(!hasUnsavedWork(images: [], shopName: "", shopAddress: "", caption: ""),
       "an untouched compose screen closes without a dialog")
assert(!hasUnsavedWork(images: [], shopName: "  ", shopAddress: "\n", caption: " \t "),
       "whitespace is not work; confirming on it would nag on every close")
assert(hasUnsavedWork(images: [photo], shopName: "", shopAddress: "", caption: ""),
       "a cropped photo is the most expensive thing here and must be confirmed")
assert(hasUnsavedWork(images: [], shopName: "Blue Bottle", shopAddress: "", caption: ""),
       "a typed shop name counts")
assert(hasUnsavedWork(images: [], shopName: "", shopAddress: "", caption: "great flat white"),
       "a typed caption counts")

// MARK: - 3. Carousel paging clamps at both ends

func nextIndex(from index: Int, count: Int) -> Int { min(index + 1, count - 1) }
func previousIndex(from index: Int) -> Int { max(index - 1, 0) }

assert(nextIndex(from: 0, count: 3) == 1, "increment advances")
assert(nextIndex(from: 2, count: 3) == 2, "increment clamps at the last photo")
assert(previousIndex(from: 1) == 0, "decrement steps back")
assert(previousIndex(from: 0) == 0, "decrement clamps at the first photo")
assert(nextIndex(from: 0, count: 1) == 0, "a single-photo carousel has nowhere to go")

print("UxPassCheck: all assertions passed")
