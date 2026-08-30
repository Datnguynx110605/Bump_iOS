import Foundation

struct ReactionService {
    let api: APIClient

    func react(postId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Reaction/post/\(postId)", method: .post))
    }

    func unreact(postId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Reaction/post/\(postId)", method: .delete))
    }

    func react(commentId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Reaction/comment/\(commentId)", method: .post))
    }

    func unreact(commentId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Reaction/comment/\(commentId)", method: .delete))
    }

    func reactions(postId: UUID, cursor: String?, pageSize: Int = 20) async throws -> CursorPage<ReactionDto> {
        try await api.send(.plain(path: "api/v1/Reaction/post/\(postId)", query: .cursor(cursor, pageSize: pageSize)))
    }

    func reactions(commentId: UUID, cursor: String?, pageSize: Int = 20) async throws -> CursorPage<ReactionDto> {
        try await api.send(.plain(path: "api/v1/Reaction/comment/\(commentId)", query: .cursor(cursor, pageSize: pageSize)))
    }
}
