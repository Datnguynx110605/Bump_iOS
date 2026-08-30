import Foundation

struct SaveService {
    let api: APIClient

    func savePost(_ postId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Save/post/\(postId)", method: .post))
    }

    func unsavePost(_ postId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Save/post/\(postId)", method: .delete))
    }

    func saveShop(_ shopId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Save/shop/\(shopId)", method: .post))
    }

    func unsaveShop(_ shopId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Save/shop/\(shopId)", method: .delete))
    }

    func myPosts(cursor: String?, pageSize: Int = 20) async throws -> CursorPage<PostSummaryDto> {
        try await api.send(.plain(path: "api/v1/Save/me/post", query: .cursor(cursor, pageSize: pageSize)))
    }

    func myShops(cursor: String?, pageSize: Int = 20) async throws -> CursorPage<ShopSummaryDto> {
        try await api.send(.plain(path: "api/v1/Save/me/shop", query: .cursor(cursor, pageSize: pageSize)))
    }
}
