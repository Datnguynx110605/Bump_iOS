import Foundation

struct ShopService {
    let api: APIClient

    func shop(id: UUID) async throws -> ShopDetailDto {
        try await api.send(.plain(path: "api/v1/Shop/\(id)"))
    }

    /// Top-rated shops within 5km of a point. The server answers a fixed top ten with a
    /// null cursor, so this is deliberately not paginated.
    func bestAround(_ coordinate: PostCoordinate) async throws -> CursorPage<ShopSummaryDto> {
        try await api.send(.plain(path: "api/v1/Shop/around", query: [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
        ]))
    }

    /// The full shop directory, newest first. Backs the Shops tab of Search before a
    /// keyword is typed, so that scope opens onto something browsable instead of a
    /// prompt to type.
    func all(cursor: String?, pageSize: Int = 20) async throws -> CursorPage<ShopSummaryDto> {
        try await api.send(.plain(path: "api/v1/Shop", query: .cursor(cursor, pageSize: pageSize)))
    }

    func search(keyword: String, cursor: String?, pageSize: Int = 20) async throws -> CursorPage<ShopSummaryDto> {
        try await api.send(.plain(
            path: "api/v1/Shop/search",
            query: [URLQueryItem(name: "keyword", value: keyword)] + .cursor(cursor, pageSize: pageSize)
        ))
    }
}
