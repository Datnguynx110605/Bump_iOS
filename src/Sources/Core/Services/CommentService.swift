import Foundation

struct CommentService {
    let api: APIClient

    func create(postId: UUID, content: String?, images: [ImageUpload]) async throws -> CommentDto {
        var form = MultipartFormData()
        form.addField(name: "postId", value: postId.uuidString)
        if let content { form.addField(name: "content", value: content) }
        for image in images {
            form.addFile(name: "images", filename: image.filename, mimeType: image.mimeType, fileData: image.data)
        }
        return try await api.send(.multipart(path: "api/v1/Comment", form: form))
    }

    func changeContent(commentId: UUID, content: String) async throws {
        let _: EmptyResponse = try await api.send(.json(
            path: "api/v1/Comment/\(commentId)", method: .put, body: ChangeContentRequest(content: content)
        ))
    }

    func delete(commentId: UUID) async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Comment/\(commentId)", method: .delete))
    }

    func byPost(_ postId: UUID, cursor: String?, pageSize: Int = 20) async throws -> CursorPage<CommentSummaryDto> {
        try await api.send(.plain(path: "api/v1/Comment/post/\(postId)", query: .cursor(cursor, pageSize: pageSize)))
    }

    func mine(cursor: String?, pageSize: Int = 20) async throws -> CursorPage<CommentSummaryDto> {
        try await api.send(.plain(path: "api/v1/Comment/mine", query: .cursor(cursor, pageSize: pageSize)))
    }
}
