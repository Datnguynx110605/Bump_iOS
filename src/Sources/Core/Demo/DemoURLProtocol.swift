#if DEBUG
import Foundation

/// Answers every API request from `DemoContent` instead of the network.
///
/// Installed only on the session `DemoMode.makeSession()` builds, which is handed to
/// `APIClient` and `AuthSession` through the injection points they already had. Requests
/// still go through the real `Endpoint` construction, the real status handling and the
/// real `APICoding.decoder`, so a fixture with the wrong shape fails here exactly as a
/// malformed server response would — which is the point of mocking at this layer rather
/// than stubbing the services.
///
/// Anything unrouted returns an empty cursor page. That is the shape of most of this
/// API's list endpoints, so an endpoint nobody thought about degrades into "nothing here
/// yet" rather than into an error screen in the middle of a screenshot.
final class DemoURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let path = request.url?.path ?? ""
        let query = URLComponents(url: request.url ?? URL(fileURLWithPath: "/"), resolvingAgainstBaseURL: false)?
            .queryItems ?? []
        let body = Self.route(path: path, method: request.httpMethod ?? "GET", query: query)

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    // MARK: - Routing

    private static func route(path: String, method: String, query: [URLQueryItem]) -> Data {
        let parts = path.split(separator: "/").map(String.init)   // ["api","v1","Post","related"]
        guard parts.count >= 3, parts[0] == "api" else { return json(emptyPage) }
        let resource = parts[2]
        let rest = Array(parts.dropFirst(3))

        switch (resource, rest.first) {
        case ("Post", "related"), ("Post", "search"):
            return json(page(posts.map(feedItem)))

        case ("Post", "mine"):
            return json(page(DemoContent.myPosts.map(summary)))

        case ("Post", "account"):
            let account = rest.count > 1 ? UUID(uuidString: rest[1]) : nil
            let owned = account == DemoContent.viewerId ? DemoContent.myPosts : posts.filter { $0.author == account }
            return json(page(owned.map(summary)))

        case ("Post", "shop"):
            let shopId = rest.count > 1 ? UUID(uuidString: rest[1]) : nil
            return json(page(allPosts.filter { $0.shop == shopId }.map(summary)))

        case ("Post", .some(let raw)):
            guard let postId = UUID(uuidString: raw), let post = allPosts.first(where: { $0.id == postId }) else {
                return json(feedItem(posts[0]))
            }
            return json(feedItem(post))

        case ("Shop", "around"), ("Shop", "search"), ("Shop", nil):
            return json(page(DemoContent.shops.map(shopSummary)))

        case ("Shop", .some(let raw)):
            let shop = UUID(uuidString: raw).flatMap { sid in DemoContent.shops.first { $0.id == sid } } ?? DemoContent.shops[0]
            return json(["shop": shopObject(shop), "isSaved": false])

        case ("Account", "me"):
            return json(accountSummary(DemoContent.viewer))

        case ("Account", "search"):
            return json(page(DemoContent.people.map(accountSummary)))

        case ("Account", .some(let raw)):
            let person = UUID(uuidString: raw).map(DemoContent.person) ?? DemoContent.viewer
            return json(accountSummary(person))

        case ("Comment", "post"):
            return json(page(DemoContent.comments.map(commentObject)))

        case ("Comment", "mine"):
            return json(page(DemoContent.comments.map(commentObject)))

        case ("Notification", "mine"):
            return json(page(DemoContent.notifications.map(noteObject)))

        case ("Save", "me") where rest.count > 1 && rest[1] == "post":
            return json(page(posts.filter(\.isSaved).map(summary)))

        case ("Save", "me") where rest.count > 1 && rest[1] == "shop":
            return json(page(DemoContent.shops.prefix(3).map(shopSummary)))

        case ("Auth", _):
            return json(["accessToken": DemoMode.accessToken, "refreshToken": "demo-refresh"])

        default:
            // Writes (like, save, follow, comment) and anything unrouted. `APIClient`
            // short-circuits `EmptyResponse` before decoding, so the body is ignored.
            return json(emptyPage)
        }
    }

    // MARK: - Shapes
    //
    // Hand-built dictionaries rather than `Encodable` mirrors of the DTOs: the DTOs are
    // `Decodable` only, and writing encoders for all of them would be a second set of
    // types to keep in sync with the server for no gain.

    private static var posts: [DemoContent.Post] { DemoContent.posts }
    private static var allPosts: [DemoContent.Post] { DemoContent.posts + DemoContent.myPosts + DemoContent.galleryPosts }

    private static let emptyPage: [String: Any] = ["items": [], "nextCursor": NSNull(), "hasMore": false]

    private static func page(_ items: [[String: Any]]) -> [String: Any] {
        ["items": items, "nextCursor": NSNull(), "hasMore": false]
    }

    private static func page(_ items: ArraySlice<[String: Any]>) -> [String: Any] { page(Array(items)) }

    private static func wrapped(_ value: Any) -> [String: Any] { ["value": value] }

    private static func date(hoursAgo: Double) -> String {
        iso.string(from: Date().addingTimeInterval(-hoursAgo * 3600))
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func image(_ name: String, hoursAgo: Double) -> [String: Any] {
        ["url": DemoMode.photoURL(name), "uploadedAt": date(hoursAgo: hoursAgo)]
    }

    private static func summary(_ p: DemoContent.Post) -> [String: Any] {
        [
            "id": p.id.uuidString,
            "accountId": p.author.uuidString,
            "shopId": p.shop.uuidString,
            "images": p.photos.map { image($0, hoursAgo: p.age) },
            "caption": p.caption,
            "rate": wrapped(p.rate),
            "reactionAmount": wrapped(p.likes),
            "commentAmount": wrapped(p.comments),
            "createdAt": date(hoursAgo: p.age),
        ]
    }

    private static func feedItem(_ p: DemoContent.Post) -> [String: Any] {
        ["post": summary(p), "isReacted": p.isLiked, "isSaved": p.isSaved]
    }

    private static func shopObject(_ s: DemoContent.Shop) -> [String: Any] {
        ["id": s.id.uuidString, "name": s.name, "address": s.address, "rate": wrapped(s.rate), "createdAt": date(hoursAgo: 720)]
    }

    private static func shopSummary(_ s: DemoContent.Shop) -> [String: Any] {
        ["id": s.id.uuidString, "name": s.name, "address": s.address, "rate": wrapped(s.rate)]
    }

    private static func avatar(_ photo: String?) -> Any {
        guard let photo else { return NSNull() }
        return ["url": DemoMode.photoURL(photo), "createdAt": date(hoursAgo: 720)]
    }

    private static func accountSummary(_ p: DemoContent.Person) -> [String: Any] {
        [
            "id": p.id.uuidString,
            "name": wrapped(p.name),
            "avatar": avatar(p.photo),
            "bio": p.bio ?? NSNull(),
            "followerAmount": wrapped(p.followers),
            "followingAmount": wrapped(p.following),
        ]
    }

    private static func commentObject(_ c: DemoContent.Comment) -> [String: Any] {
        [
            "id": c.id.uuidString,
            "accountId": c.author.uuidString,
            "content": c.text,
            "images": [],
            "reactionAmount": wrapped(c.likes),
            "createdAt": date(hoursAgo: c.age),
        ]
    }

    private static func noteObject(_ n: DemoContent.Note) -> [String: Any] {
        [
            "id": n.id.uuidString,
            "toAccountId": DemoContent.viewerId.uuidString,
            "title": n.title,
            "content": n.content,
            "isSent": true,
            "createdAt": date(hoursAgo: n.age),
            "type": n.type,
            "targetId": n.target.uuidString,
            "actorAccountId": n.actor.uuidString,
            "actorAvatar": avatar(DemoContent.person(n.actor).photo),
        ]
    }

    private static func json(_ object: Any) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
    }
}
#endif
