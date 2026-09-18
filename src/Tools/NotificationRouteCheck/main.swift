// Checks that a notification payload from the server resolves to the route the client
// navigates to. Compiles the real Sources/Core/Models/NotificationModels.swift, so it
// tests the shipping decoder rather than a copy of it.
//
// This guards a contract split across two repositories: Bump_Server's
// NotificationProjection decides which fields reach the client, and a Mongo inclusion
// projection returns *only* the fields it names. When Type and TargetId were missing
// from that projection the endpoint still answered 200 with nulls, every route came back
// nil, and the whole notification list silently stopped being tappable.
//
// It also guards the APNs payload, whose `type`/`targetId` keys are read by
// AppRoute(pushPayload:) in NotificationModels.swift and written by Bump_Server's
// ApnsService — a second contract with nothing enforcing it at compile time.
//
//   cd Bump_Client/src
//   swiftc -o /tmp/routecheck \
//       Sources/Core/Models/NotificationModels.swift \
//       Sources/Core/Models/AccountModels.swift \
//       Sources/Core/Networking/Wrapped.swift \
//       Sources/Core/Networking/Endpoint.swift \
//       Sources/Core/Networking/HTTPMethod.swift \
//       Sources/Core/Networking/MultipartFormData.swift \
//       Tools/NotificationRouteCheck/*.swift && /tmp/routecheck

import Foundation

// Payload shaped exactly as the server now returns it: camelCase keys from
// System.Text.Json web defaults, NotificationType as an integer (no
// JsonStringEnumConverter is registered on either pipeline), .NET date strings.
func payload(type: Int, targetId: String) -> Data {
    Data("""
    {
      "id": "6C1B0F3E-2A44-4E1C-9C21-6C4D0A1B2E33",
      "toAccountId": "11111111-1111-1111-1111-111111111111",
      "title": "New comment",
      "content": "ana commented on your post",
      "isSent": true,
      "createdAt": "2026-09-07T10:15:30.1234567Z",
      "type": \(type),
      "targetId": "\(targetId)",
      "actorAccountId": "22222222-2222-2222-2222-222222222222",
      "actorAvatar": { "url": "https://cdn.example/a.jpg", "createdAt": "2026-09-01T08:00:00Z" }
    }
    """.utf8)
}

let target = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

// domain.NotificationType: Follow = 0, PostReaction = 1, CommentReaction = 2, Comment = 3.
// TargetId is the account for Follow and the post for the other three.
let expected: [(Int, AppRoute)] = [
    (0, .account(target)),
    (1, .post(target)),
    (2, .post(target)),
    (3, .post(target)),
]

for (raw, route) in expected {
    let dto = try! APICoding.decoder.decode(
        NotificationSummaryDto.self,
        from: payload(type: raw, targetId: target.uuidString))
    assert(dto.type?.rawValue == raw, "type \(raw) failed to decode")
    assert(dto.targetId == target, "targetId dropped for type \(raw)")
    assert(dto.route == route, "type \(raw) routed to \(String(describing: dto.route)), expected \(route)")
    assert(dto.actorAvatar?.url == "https://cdn.example/a.jpg", "actor avatar dropped")
}

// The regression itself: this is what the endpoint returned while the projection omitted
// Type and TargetId. A nil route is what made every row in the list untappable.
let stripped = Data("""
{ "id": "6C1B0F3E-2A44-4E1C-9C21-6C4D0A1B2E33",
  "toAccountId": "11111111-1111-1111-1111-111111111111",
  "title": "New comment", "content": "ana commented on your post",
  "isSent": true, "createdAt": "2026-09-07T10:15:30.1234567Z",
  "type": null, "targetId": null, "actorAccountId": null, "actorAvatar": null }
""".utf8)
let dead = try! APICoding.decoder.decode(NotificationSummaryDto.self, from: stripped)
assert(dead.route == nil, "a notification with no type/targetId must not produce a route")

// An enum value this client build doesn't know must degrade to an untappable row, not
// fail the whole list decode.
let future = try! APICoding.decoder.decode(
    NotificationSummaryDto.self,
    from: payload(type: 99, targetId: target.uuidString))
assert(future.route == nil, "unknown type should yield no route")
assert(future.title == "New comment", "unknown type must not break the rest of the decode")

// The same four types again, this time through the APNs payload. Nothing enforces the
// contract between the two repositories at compile time: Bump_Server writes `type` and
// `targetId` as custom keys on the push, and this initializer is the only thing that reads
// them. APNs delivers the payload as a dictionary, so the integer arrives as NSNumber.
for (raw, route) in expected {
    let userInfo: [AnyHashable: Any] = [
        "notificationId": "6C1B0F3E-2A44-4E1C-9C21-6C4D0A1B2E33",
        "type": raw,
        "targetId": target.uuidString,
    ]
    assert(AppRoute(pushPayload: userInfo) == route, "push type \(raw) routed to the wrong screen")
}

// A malformed or partial payload must yield no route rather than a wrong one: a tap that
// does nothing beats a tap that opens someone else's post.
assert(AppRoute(pushPayload: ["type": 1]) == nil, "missing targetId must not route")
assert(AppRoute(pushPayload: ["targetId": target.uuidString]) == nil, "missing type must not route")
assert(AppRoute(pushPayload: ["type": 99, "targetId": target.uuidString]) == nil, "unknown push type must not route")
assert(
    AppRoute(pushPayload: ["type": 1, "targetId": "not-a-uuid"]) == nil,
    "unparseable targetId must not route")

print("route resolution OK — 4 notification types over REST and APNs, null-field regression, unknown type")
