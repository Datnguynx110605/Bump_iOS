// Checks the client half of the block and edit features that Bump_Server added, by
// compiling the real shipping model files rather than copies of them.
//
// Three things are worth a check here:
//
//  1. `BlockDto` decoding. The server returns `Name` as a *wrapped object*
//     (`{"value": "ana"}`), not a bare string — `NameJsonConverter` exists in `infra`
//     but is never registered on the API's MVC JSON pipeline, so `Name` falls through
//     to default reflection serialization. A future registration of that converter
//     would flip the wire format and break every `Wrapped<String>` field silently.
//  2. `FreeTextRule` boundaries against `ChangeCaptionValidator`/`ChangeContentValidator`,
//     which cap at 2000 and use `.NotNull()` rather than `.NotEmpty()` — clearing a
//     caption is a legitimate edit and must not be rejected client-side.
//  3. `CommentSummaryDto.withContent`, which applies an edit locally because
//     `PUT /Comment/{id}` answers with no body.
//  4. `Array.isNearEnd`, which every one of the app's eleven paginated lists now uses to
//     decide when to fetch the next page. It replaced an exact-tail comparison that
//     stalled whenever the real last row was filtered out of the rendered list.
//
//   cd Bump_Client/src
//   swiftc -o /tmp/blockeditcheck \
//       Sources/Core/Models/BlockModels.swift \
//       Sources/Core/Models/AccountModels.swift \
//       Sources/Core/Models/CommentModels.swift \
//       Sources/Core/Models/PostModels.swift \
//       Sources/Core/Models/Pagination.swift \
//       Sources/Core/Networking/Wrapped.swift \
//       Sources/Core/Networking/Endpoint.swift \
//       Sources/Core/Networking/HTTPMethod.swift \
//       Sources/Core/Networking/MultipartFormData.swift \
//       Sources/Core/Utilities/Validation.swift \
//       Tools/BlockAndEditCheck/*.swift && /tmp/blockeditcheck

import Foundation

// MARK: - 1. BlockDto decodes the shape GET /Block/me actually returns

let blockPage = Data("""
{
  "items": [
    {
      "accountId": "22222222-2222-2222-2222-222222222222",
      "name": { "value": "ana" },
      "avatar": { "url": "https://cdn.example/a.jpg", "createdAt": "2026-09-01T08:00:00Z" },
      "blockedAt": "2026-09-09T10:15:30.1234567Z"
    },
    {
      "accountId": "33333333-3333-3333-3333-333333333333",
      "name": { "value": "bo" },
      "avatar": null,
      "blockedAt": "2026-09-08T09:00:00Z"
    }
  ],
  "nextCursor": "eyJiIjoxfQ==",
  "hasMore": true
}
""".utf8)

let page = try APICoding.decoder.decode(CursorPage<BlockDto>.self, from: blockPage)
assert(page.items.count == 2, "expected 2 blocked accounts, got \(page.items.count)")
assert(page.items[0].name.value == "ana", "Name must decode from {\"value\": ...}")
assert(page.items[0].id == page.items[0].accountId, "BlockDto.id must key off accountId for ForEach")
assert(page.items[0].avatar?.url == "https://cdn.example/a.jpg")
assert(page.items[1].avatar == nil, "a blocked account with no avatar must decode, not throw")
assert(page.hasMore && page.nextCursor != nil, "pagination fields must survive decoding")
// 7-digit .NET fractional seconds are longer than ISO8601DateFormatter accepts natively.
assert(page.items[0].blockedAt > page.items[1].blockedAt, "blockedAt must parse .NET precision")

// MARK: - 2. FreeTextRule matches the server's validators

assert(FreeTextRule.maxLength == 2000, "server caps caption and content at 2000")
assert(FreeTextRule.isValid(""), "clearing a caption is a legitimate edit — .NotNull(), not .NotEmpty()")
assert(FreeTextRule.isValid(String(repeating: "a", count: 2000)), "2000 is inclusive")
assert(!FreeTextRule.isValid(String(repeating: "a", count: 2001)), "2001 must be rejected before the request")

assert(FreeTextRule.remaining("") == nil, "counter stays hidden while the limit is far away")
assert(FreeTextRule.remaining(String(repeating: "a", count: 1799)) == nil, "still hidden one char early")
assert(FreeTextRule.remaining(String(repeating: "a", count: 1800)) == 200, "counter appears exactly at the threshold")
assert(FreeTextRule.remaining(String(repeating: "a", count: 2000)) == 0, "zero left is still shown")
assert(FreeTextRule.remaining(String(repeating: "a", count: 2010)) == -10, "over the limit reads negative, not nil")

// MARK: - 3. withContent applies an edit without disturbing anything else

let original = try APICoding.decoder.decode(CommentSummaryDto.self, from: Data("""
{
  "id": "44444444-4444-4444-4444-444444444444",
  "accountId": "22222222-2222-2222-2222-222222222222",
  "content": "before",
  "images": [{ "url": "https://cdn.example/c.jpg", "uploadedAt": "2026-09-01T08:00:00Z" }],
  "reactionAmount": { "value": 7 },
  "createdAt": "2026-09-09T10:15:30.1234567Z"
}
""".utf8))

let edited = original.withContent("after")
assert(edited.content == "after")
assert(edited.id == original.id, "identity must survive, or ForEach reorders the row")
assert(edited.accountId == original.accountId)
assert(edited.images == original.images, "editing text must not drop the photos")
assert(edited.reactionAmount.value == original.reactionAmount.value, "likes are not part of the edit")
assert(edited.createdAt == original.createdAt, "an edit is not a repost")

// An image-only comment can gain text; its images stay as posted.
let imageOnly = try APICoding.decoder.decode(CommentSummaryDto.self, from: Data("""
{
  "id": "55555555-5555-5555-5555-555555555555",
  "accountId": "22222222-2222-2222-2222-222222222222",
  "content": null,
  "images": [{ "url": "https://cdn.example/d.jpg", "uploadedAt": "2026-09-01T08:00:00Z" }],
  "reactionAmount": { "value": 0 },
  "createdAt": "2026-09-09T10:15:30Z"
}
""".utf8))
assert(imageOnly.content == nil)
assert(imageOnly.withContent("now with words").images.count == 1)

// MARK: - 4. Edit requests encode the field names the controllers bind

func encodedKeys<T: Encodable>(_ value: T) throws -> Set<String> {
    let data = try APICoding.encoder.encode(value)
    let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    return Set(object.keys)
}

let captionKeys = try encodedKeys(ChangeCaptionRequest(caption: "x"))
let rateKeys = try encodedKeys(ChangeRateRequest(rate: 4))
let contentKeys = try encodedKeys(ChangeContentRequest(content: "x"))
assert(captionKeys == ["caption"], "PostController binds ChangeCaptionRequest.Caption")
assert(rateKeys == ["rate"], "PostController binds ChangeRateRequest.Rate")
assert(contentKeys == ["content"], "CommentController binds ChangeContentRequest.Content")

// MARK: - 5. isNearEnd pages from a window, not one exact element

struct Row: Identifiable, Equatable { let id: Int }
let rows = (0..<10).map(Row.init)

assert(rows.isNearEnd(rows[9]), "the true last row must page")
assert(rows.isNearEnd(rows[7]), "the default window is the last three rows")
assert(!rows.isNearEnd(rows[6]), "one row before the window must not page")
assert(!rows.isNearEnd(Row(id: 99)), "an item not in the list must never page")

// The regression this replaced: hide the tail — a blocked author's post — and the last
// row the user can actually see still has to trigger the next page.
let rendered = Array(rows.dropLast())
assert(rendered.isNearEnd(rows[8]), "last *visible* row must page when the true tail is filtered out")
// Filtering several from the tail is still covered by the window.
assert(Array(rows.dropLast(2)).isNearEnd(rows[7]), "two filtered from the tail still pages")

// Shorter than the window, and empty.
assert([Row(id: 0)].isNearEnd(Row(id: 0)), "a one-item list still pages")
assert(![Row]().isNearEnd(Row(id: 0)), "an empty list has nothing to page from")

// Constant cost regardless of how many pages have accumulated.
let huge = (0..<50_000).map(Row.init)
assert(huge.isNearEnd(huge[49_999]))
assert(!huge.isNearEnd(huge[0]), "must not scan the whole list to answer")

print("BlockAndEditCheck: all checks passed")
