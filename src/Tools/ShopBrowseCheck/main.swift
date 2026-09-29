// Checks the client half of the shop-directory browse added for parity with
// `GET /api/v1/Shop`, plus the compose-screen validation that now mirrors
// `CreatePostValidator` instead of letting the server reject an upload.
//
// Three things are worth a check here:
//
//  1. `CursorPage<ShopSummaryDto>` decoding. `ShopSummaryDto.Rate` is a domain `Amount`
//     that crosses the wire as `{"value": 4}` — `AmountJsonConverter` exists in `infra`
//     but is registered only on the Redis pipeline, never on MVC — while `Name` and
//     `Address` on that same DTO are plain `string`. The asymmetry is easy to "tidy"
//     into a break, so it is pinned here.
//  2. The directory paging state machine. It is the one piece of new logic: a cursor, a
//     `hasMore` flag and a once-only guard that has to release on failure, or a first
//     load cancelled by a tab switch would pin an empty directory for the life of the
//     screen. A genuine failure has to stay distinguishable from an empty directory, and
//     the retry behind the error state has to bypass the once-only guard the ordinary
//     appearance path honours.
//  3. The caption ceiling shared with the edit sheets.
//
//   cd Bump_iOS/src
//   swiftc -o /tmp/shopbrowsecheck \
//       Sources/Core/Models/ShopModels.swift \
//       Sources/Core/Models/Pagination.swift \
//       Sources/Core/Networking/Wrapped.swift \
//       Sources/Core/Utilities/Validation.swift \
//       Tools/ShopBrowseCheck/*.swift && /tmp/shopbrowsecheck

import Foundation

// MARK: - 1. GET /Shop decodes into the page the directory renders

let directoryPage = Data("""
{
  "items": [
    { "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301", "name": "Blue Bottle", "address": "12 Pike St", "rate": { "value": 5 } },
    { "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3302", "name": "Cafe Nero", "address": "88 Elm Rd", "rate": { "value": 3 } }
  ],
  "nextCursor": "eyJpZCI6Mn0=",
  "hasMore": true
}
""".utf8)

let page = try JSONDecoder().decode(CursorPage<ShopSummaryDto>.self, from: directoryPage)
assert(page.items.count == 2, "expected two shops, got \(page.items.count)")
assert(page.items[0].name == "Blue Bottle", "name is a bare string on ShopSummaryDto")
assert(page.items[0].address == "12 Pike St", "address is a bare string on ShopSummaryDto")
// The asymmetry that matters: rate is wrapped, its siblings are not.
assert(page.items[0].rate.value == 5, "rate crosses the wire as {\"value\": Int}")
assert(page.items[1].rate.value == 3)
assert(page.nextCursor == "eyJpZCI6Mn0=")
assert(page.hasMore)

// A last page carries a null cursor and stops paging.
let lastPage = try JSONDecoder().decode(CursorPage<ShopSummaryDto>.self, from: Data("""
{ "items": [], "nextCursor": null, "hasMore": false }
""".utf8))
assert(lastPage.items.isEmpty)
assert(lastPage.nextCursor == nil)
assert(!lastPage.hasMore)

// MARK: - 2. The directory paging state machine

/// Mirrors the cursor/hasMore/once-only trio `SearchViewModel` keeps for the directory,
/// so the guard logic can be exercised without a network or an @Observable class.
struct DirectoryPager {
    private(set) var items: [ShopSummaryDto] = []
    private(set) var cursor: String?
    private(set) var hasMore = true
    private(set) var hasLoaded = false
    private(set) var requests = 0
    /// Mirrors `directoryError`: nil for a cancelled request, a message for a real
    /// failure. The view keys its error state off this, so an empty directory and a
    /// failed lookup stay distinguishable.
    private(set) var error: String?

    enum Outcome {
        case page(CursorPage<ShopSummaryDto>)
        case cancelled
        case failed(String)
    }

    /// Returns false when the guard refused the call, mirroring the early `return`.
    @discardableResult
    mutating func loadFirst(_ outcome: Outcome) -> Bool {
        guard !hasLoaded else { return false }
        load(outcome)
        return true
    }

    /// The retry behind the error state, which must bypass the once-only guard.
    mutating func retry(_ outcome: Outcome) {
        load(outcome)
    }

    private mutating func load(_ outcome: Outcome) {
        hasLoaded = true
        requests += 1
        error = nil
        switch outcome {
        case .page(let result):
            items = result.items
            cursor = result.nextCursor
            hasMore = result.hasMore
        case .cancelled:
            // Releasing the guard is the whole point: a cancelled first load must be
            // retryable on the next appearance, and must not paint an error.
            hasLoaded = false
        case .failed(let message):
            hasLoaded = false
            error = message
        }
    }

    @discardableResult
    mutating func loadMore(_ result: CursorPage<ShopSummaryDto>?) -> Bool {
        guard hasMore else { return false }
        requests += 1
        guard let result else { return true }
        items.append(contentsOf: result.items)
        cursor = result.nextCursor
        hasMore = result.hasMore
        return true
    }
}

var pager = DirectoryPager()
assert(pager.loadFirst(.page(page)), "first load must run")
assert(pager.items.count == 2)
assert(pager.cursor == "eyJpZCI6Mn0=")
assert(pager.error == nil)

// Appearing again must not refetch a directory already held.
assert(!pager.loadFirst(.page(page)), "second loadFirst must be refused by the once-only guard")
assert(pager.requests == 1, "guard must not spend a second request")

// Paging appends and carries the cursor forward.
let secondPage = try JSONDecoder().decode(CursorPage<ShopSummaryDto>.self, from: Data("""
{
  "items": [{ "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3303", "name": "Third Wave", "address": "5 Oak Ln", "rate": { "value": 4 } }],
  "nextCursor": null,
  "hasMore": false
}
""".utf8))
assert(pager.loadMore(secondPage))
assert(pager.items.count == 3, "page two must append, not replace")
assert(pager.items.map(\.name) == ["Blue Bottle", "Cafe Nero", "Third Wave"], "page order must be preserved")
assert(pager.cursor == nil)
assert(!pager.hasMore)

// Exhausted means exhausted — no request once hasMore is false.
let requestsBefore = pager.requests
assert(!pager.loadMore(secondPage), "paging past the end must be refused")
assert(pager.requests == requestsBefore, "no request may be spent past the end")

// A cancelled first load leaves the screen able to try again, and says nothing — the
// user switched tabs, the server is fine.
var cancelled = DirectoryPager()
assert(cancelled.loadFirst(.cancelled))
assert(cancelled.items.isEmpty)
assert(cancelled.error == nil, "a cancelled load must not surface an error")
assert(!cancelled.hasLoaded, "a cancelled first load must release the guard")
assert(cancelled.loadFirst(.page(page)), "retry after cancellation must be allowed")
assert(cancelled.items.count == 2)

// A genuine failure must stay distinguishable from an empty directory, or the screen
// says "No shops yet" about a request that simply failed.
var failing = DirectoryPager()
assert(failing.loadFirst(.failed("Couldn't connect.")))
assert(failing.items.isEmpty)
assert(failing.error == "Couldn't connect.", "a real failure must be reportable")
assert(!failing.hasLoaded, "a failed first load must release the guard")

// The retry behind the error state bypasses the once-only guard and clears the error.
failing.retry(.page(page))
assert(failing.items.count == 2, "retry must populate the directory")
assert(failing.error == nil, "a successful retry must clear the error")
assert(failing.hasLoaded)

// Retrying a directory that already loaded is still allowed — the error state is gone by
// then, but nothing about `retry` may depend on the guard's state.
var reloading = DirectoryPager()
assert(reloading.loadFirst(.page(page)))
reloading.retry(.page(page))
assert(reloading.requests == 2, "retry must bypass the once-only guard")

// MARK: - 3. Caption ceiling
//
// Shop name and address rules used to be checked here against `CreatePostValidator`.
// They are gone: the compose screen no longer sends either field, only a place
// identifier picked from Apple Maps, so there is no client-side shop text left to bound.
// `CreatePostCheck` covers what replaced them.
assert(FreeTextRule.isValid(""), "clearing a caption is a legitimate edit")
assert(FreeTextRule.isValid(String(repeating: "b", count: 2000)))
assert(!FreeTextRule.isValid(String(repeating: "b", count: 2001)))
assert(FreeTextRule.remaining(String(repeating: "b", count: 2001)) == -1, "over-limit must report negative, which drives the error tone")
assert(FreeTextRule.remaining("short") == nil, "counter stays hidden far from the limit")

print("ShopBrowseCheck: all assertions passed")
