import Foundation

struct PostService {
    let api: APIClient

    /// Either a place identifier or a typed name and address. With an identifier the
    /// server resolves the shop from Apple and ignores any shop text sent with it, so the
    /// caller sends one or the other rather than both.
    func create(
        placeId: String?,
        shopName: String?,
        shopAddress: String?,
        coordinate: PostCoordinate?,
        caption: String?,
        rate: Int,
        images: [ImageUpload]
    ) async throws -> PostDto {
        var form = MultipartFormData()
        if let placeId { form.addField(name: "placeId", value: placeId) }
        if let shopName { form.addField(name: "shopName", value: shopName) }
        if let shopAddress { form.addField(name: "shopAddress", value: shopAddress) }
        // The server rejects a half-supplied pair ("Latitude and longitude must be
        // provided together"), so both fields are added or neither is.
        if let coordinate {
            form.addField(name: "latitude", value: String(coordinate.latitude))
            form.addField(name: "longitude", value: String(coordinate.longitude))
        }
        if let caption { form.addField(name: "caption", value: caption) }
        form.addField(name: "rate", value: String(rate))
        for image in images {
            form.addFile(name: "images", filename: image.filename, mimeType: image.mimeType, fileData: image.data)
        }
        return try await api.send(.multipart(path: "api/v1/Post", form: form))
    }

    func changeCaption(postId: UUID, caption: String) async throws {
        let _: EmptyResponse = try await api.send(.json(
            path: "api/v1/Post/\(postId)/caption", method: .put, body: ChangeCaptionRequest(caption: caption)
        ))
    }

    func changeRate(postId: UUID, rate: Int) async throws {
        let _: EmptyResponse = try await api.send(.json(
            path: "api/v1/Post/\(postId)/rate", method: .put, body: ChangeRateRequest(rate: rate)
        ))
    }

    func delete(postId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Post/\(postId)", method: .delete))
    }

    func post(id: UUID) async throws -> PostFeedItemDto {
        try await api.send(.plain(path: "api/v1/Post/\(id)"))
    }

    func mine(cursor: String?, pageSize: Int = 20) async throws -> CursorPage<PostSummaryDto> {
        try await api.send(.plain(path: "api/v1/Post/mine", query: .cursor(cursor, pageSize: pageSize)))
    }

    func byAccount(_ accountId: UUID, cursor: String?, pageSize: Int = 20) async throws -> CursorPage<PostSummaryDto> {
        try await api.send(.plain(path: "api/v1/Post/account/\(accountId)", query: .cursor(cursor, pageSize: pageSize)))
    }

    func byShop(_ shopId: UUID, cursor: String?, pageSize: Int = 20) async throws -> CursorPage<PostSummaryDto> {
        try await api.send(.plain(path: "api/v1/Post/shop/\(shopId)", query: .cursor(cursor, pageSize: pageSize)))
    }

    /// The personalized feed: a blend of the accounts the viewer follows, the ones they
    /// react to, widely-followed accounts, and shops near `coordinate`.
    ///
    /// The coordinate is what gives the nearby tier anything to draw from — without one
    /// the server falls to a mix that has no nearby share at all. `mode` is deliberately
    /// not sent: the server derives it from whether a cursor came with the request, and
    /// pins the origin on the first page, so a coordinate sent while paging is ignored
    /// rather than able to shift the feed under the reader.
    func related(
        cursor: String?,
        coordinate: PostCoordinate?,
        pageSize: Int = 20
    ) async throws -> CursorPage<PostFeedItemDto> {
        var query: [URLQueryItem] = .cursor(cursor, pageSize: pageSize)
        if let coordinate {
            query.append(URLQueryItem(name: "latitude", value: String(coordinate.latitude)))
            query.append(URLQueryItem(name: "longitude", value: String(coordinate.longitude)))
        }
        return try await api.send(.plain(path: "api/v1/Post/related", query: query))
    }

    func search(keyword: String, cursor: String?, pageSize: Int = 20) async throws -> CursorPage<PostFeedItemDto> {
        try await api.send(.plain(
            path: "api/v1/Post/search",
            query: [URLQueryItem(name: "keyword", value: keyword)] + .cursor(cursor, pageSize: pageSize)
        ))
    }
}
