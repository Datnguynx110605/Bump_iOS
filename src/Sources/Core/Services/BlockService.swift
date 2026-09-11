import Foundation

struct BlockService {
    let api: APIClient

    func block(_ accountId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Block/\(accountId)", method: .post))
    }

    func unblock(_ accountId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Block/\(accountId)", method: .delete))
    }

    func mine(cursor: String?, pageSize: Int = 20) async throws -> CursorPage<BlockDto> {
        try await api.send(.plain(path: "api/v1/Block/me", query: .cursor(cursor, pageSize: pageSize)))
    }
}
