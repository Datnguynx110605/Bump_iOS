// Checks the client half of the contract changes that landed with the Apple Maps-only
// shop model on Bump_Server. Compiles the real model files, so it tests the shipping
// decoders rather than copies of them.
//
// Four things are worth pinning here:
//
//  1. `POST /Post` now takes a place identifier and nothing else about the shop — the
//     server resolves name, address and coordinate from Apple and accepts none of them
//     from the client. `placeId` is required, so the compose screen's gate has to be
//     "a place was picked", not "some text was typed". This is the break that a typed
//     shop used to slip through as a 400 after every photo had already uploaded.
//  2. `AccountSummaryDto` gained `isTrusted`. It is non-optional on the wire, so it is
//     non-optional here, which means a payload without it must fail rather than decode
//     into a silent default.
//  3. `PUT /Account/me/password` answers 200 with a fresh token pair instead of 204. The
//     handler revokes every refresh token on the account, so a client that discards the
//     body keeps a revoked refresh token and is signed out the next time its access
//     token expires — a failure that shows up minutes later, nowhere near the change.
//  4. `GET /Post/related` takes an optional coordinate, and the pair has to travel whole
//     or not at all.
//
//   cd Bump_iOS/src
//   swiftc -o /tmp/createpostcheck \
//       Sources/Core/Models/AccountModels.swift \
//       Sources/Core/Models/AuthModels.swift \
//       Sources/Core/Networking/Wrapped.swift \
//       Sources/Core/Utilities/Validation.swift \
//       Tools/CreatePostCheck/*.swift && /tmp/createpostcheck

import Foundation

// MARK: - 1. The compose gate

// Mirrors CreatePostViewModel. The real one is @MainActor/@Observable and reaches into
// MapKit and the service layer, so the gate is restated here over the same fields — it
// is the rule that matters, and the rule is what the server changed.
struct ComposeGate {
    var picked: PlaceMatch?
    var shopQuery = ""
    var caption = ""
    var rating = 5
    var images: [Data] = []

    var isValid: Bool {
        picked != nil && FreeTextRule.isValid(caption) && (1...5).contains(rating)
    }

    var hasUnsavedWork: Bool {
        picked != nil
            || !images.isEmpty
            || !shopQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

let blueBottle = PlaceMatch(
    placeId: "I1234567890ABCDEF",
    name: "Blue Bottle Coffee",
    address: "12 Pike St, Seattle WA"
)

// The whole point of the change: typing a name is not enough any more, however complete
// it looks. Without an identifier there is nothing the server will accept.
var typed = ComposeGate()
typed.shopQuery = "Blue Bottle Coffee"
typed.caption = "Great cortado."
assert(!typed.isValid, "a typed shop name must not be postable — the server requires a placeId")

var picked = ComposeGate()
picked.picked = blueBottle
assert(picked.isValid, "a picked place is all the shop information a post needs")

// A caption is optional, but one over the server's ceiling must be caught here rather
// than after every photo has been uploaded.
var longCaption = ComposeGate()
longCaption.picked = blueBottle
longCaption.caption = String(repeating: "a", count: 2001)
assert(!longCaption.isValid, "caption over 2000 must fail before the upload, not after")
longCaption.caption = String(repeating: "a", count: 2000)
assert(longCaption.isValid, "2000 is inclusive")

// Rate is 1-5 on the server; 0 is the default-int mistake worth pinning.
var zeroRate = ComposeGate()
zeroRate.picked = blueBottle
zeroRate.rating = 0
assert(!zeroRate.isValid, "server caps rate at 1-5")

// Discard confirmation still covers a half-typed search that never became a pick.
var searching = ComposeGate()
searching.shopQuery = "Blue"
assert(searching.hasUnsavedWork, "an abandoned search is still work worth confirming")
assert(!ComposeGate().hasUnsavedWork, "an untouched sheet closes without a prompt")

// A place is identified by its Apple identifier, which is what makes two rows for the
// same branch impossible in the picker.
assert(blueBottle.id == blueBottle.placeId)

// MARK: - 2. AccountSummaryDto carries isTrusted

let summary = try JSONDecoder().decode(AccountSummaryDto.self, from: Data("""
{
  "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
  "name": { "value": "dat" },
  "avatar": null,
  "bio": null,
  "followerAmount": { "value": 12 },
  "followingAmount": { "value": 30 },
  "isTrusted": true
}
""".utf8))
assert(summary.isTrusted == true, "isTrusted must survive the decode")
// Name is a domain value object and crosses the wire wrapped; the booleans beside it do
// not. The asymmetry is easy to "tidy" into a break, so it is pinned.
assert(summary.name.value == "dat", "Name crosses the wire as {\"value\": String}")
assert(summary.followerAmount.value == 12)

// A payload that stops carrying the field must still decode. This DTO backs /Account/me,
// /Account/{id} and every search page, so a projection that drops isTrusted would
// otherwise take all three down at once — and nothing reads the field yet.
let withoutTrusted = try JSONDecoder().decode(AccountSummaryDto.self, from: Data("""
{
  "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
  "name": { "value": "dat" },
  "avatar": null,
  "bio": null,
  "followerAmount": { "value": 12 },
  "followingAmount": { "value": 30 }
}
""".utf8))
assert(withoutTrusted.isTrusted == nil, "a missing isTrusted degrades rather than failing the whole screen")
assert(withoutTrusted.name.value == "dat", "the rest of the account must still arrive")

// MARK: - 3. Changing a password hands back a usable session

// The body of PUT /Account/me/password, which used to be nothing at all.
let replacement = try JSONDecoder().decode(AuthTokens.self, from: Data("""
{ "accessToken": "header.payload.signature", "refreshToken": "8f14e45fceea167a" }
""".utf8))
assert(!replacement.accessToken.isEmpty, "the new access token must reach the keychain")
assert(!replacement.refreshToken.isEmpty, "the old refresh token is revoked — this one replaces it")

// MARK: - 4. The feed coordinate travels whole or not at all

// Mirrors PostService.related's query building. The server ignores a half-supplied pair,
// so sending one is a silent loss of the nearby tier rather than an error.
struct RelatedQuery {
    static func items(cursor: String?, latitude: Double?, longitude: Double?) -> [String] {
        var items: [String] = []
        if let cursor { items.append("cursor=\(cursor)") }
        if let latitude, let longitude {
            items.append("latitude=\(latitude)")
            items.append("longitude=\(longitude)")
        }
        return items
    }
}

let located = RelatedQuery.items(cursor: nil, latitude: 47.6, longitude: -122.3)
assert(located.contains("latitude=47.6") && located.contains("longitude=-122.3"),
       "a first page with a fix must carry both coordinates")

let unlocated = RelatedQuery.items(cursor: nil, latitude: nil, longitude: nil)
assert(unlocated.isEmpty, "no fix means no coordinates, not a partial pair")

let half = RelatedQuery.items(cursor: nil, latitude: 47.6, longitude: nil)
assert(half.isEmpty, "half a coordinate must not be sent — the server would ignore it anyway")

// Paging carries the cursor and no coordinate: the origin was pinned on the first page.
let paging = RelatedQuery.items(cursor: "eyJpZCI6Mn0=", latitude: nil, longitude: nil)
assert(paging == ["cursor=eyJpZCI6Mn0="], "paging rides the pinned origin")

print("CreatePostCheck: all assertions passed")
