import Foundation

struct ShopService {
    let api: APIClient

    func shop(id: UUID) async throws -> ShopDetailDto {
        try await api.send(.plain(path: "api/v1/Shop/\(id)"))
    }

    func all(cursor: String?, pageSize: Int = 20) async throws -> CursorPage<ShopSummaryDto> {
        try await api.send(.plain(path: "api/v1/Shop", query: .cursor(cursor, pageSize: pageSize)))
    }

    func search(keyword: String, cursor: String?, pageSize: Int = 20) async throws -> CursorPage<ShopSummaryDto> {
        try await api.send(.plain(
            path: "api/v1/Shop/search",
            query: [URLQueryItem(name: "keyword", value: keyword)] + .cursor(cursor, pageSize: pageSize)
        ))
    }

    func mostRated(cursor: String?, pageSize: Int = 20) async throws -> CursorPage<ShopSummaryDto> {
        try await api.send(.plain(path: "api/v1/Shop/most-rated", query: .cursor(cursor, pageSize: pageSize)))
    }
}
