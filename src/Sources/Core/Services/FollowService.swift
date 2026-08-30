import Foundation

struct FollowService {
    let api: APIClient

    func follow(_ accountId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Follow/\(accountId)", method: .post))
    }

    func unfollow(_ accountId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Follow/\(accountId)", method: .delete))
    }

    func followers(of accountId: UUID, cursor: String?, pageSize: Int = 20) async throws -> CursorPage<FollowerDto> {
        try await api.send(.plain(path: "api/v1/Follow/follower/\(accountId)", query: .cursor(cursor, pageSize: pageSize)))
    }

    func following(of accountId: UUID, cursor: String?, pageSize: Int = 20) async throws -> CursorPage<FollowingDto> {
        try await api.send(.plain(path: "api/v1/Follow/following/\(accountId)", query: .cursor(cursor, pageSize: pageSize)))
    }

    func myFollowers(cursor: String?, pageSize: Int = 20) async throws -> CursorPage<FollowerDto> {
        try await api.send(.plain(path: "api/v1/Follow/me/follower", query: .cursor(cursor, pageSize: pageSize)))
    }

    func myFollowing(cursor: String?, pageSize: Int = 20) async throws -> CursorPage<FollowingDto> {
        try await api.send(.plain(path: "api/v1/Follow/me/following", query: .cursor(cursor, pageSize: pageSize)))
    }
}
