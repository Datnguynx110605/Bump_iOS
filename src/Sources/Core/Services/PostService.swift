import Foundation

struct PostService {
    let api: APIClient

    func create(
        shopName: String,
        shopAddress: String,
        coordinate: PostCoordinate?,
        caption: String?,
        rate: Int,
        images: [ImageUpload]
    ) async throws -> PostDto {
        var form = MultipartFormData()
        form.addField(name: "shopName", value: shopName)
        form.addField(name: "shopAddress", value: shopAddress)
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

    /// The personalized feed: posts from accounts the viewer follows or has reacted to.
    /// Replaces the removed `/latest` and `/most-reacted` endpoints.
    func related(cursor: String?, pageSize: Int = 20) async throws -> CursorPage<PostFeedItemDto> {
        try await api.send(.plain(path: "api/v1/Post/related", query: .cursor(cursor, pageSize: pageSize)))
    }

    func search(keyword: String, cursor: String?, pageSize: Int = 20) async throws -> CursorPage<PostFeedItemDto> {
        try await api.send(.plain(
            path: "api/v1/Post/search",
            query: [URLQueryItem(name: "keyword", value: keyword)] + .cursor(cursor, pageSize: pageSize)
        ))
    }
}
