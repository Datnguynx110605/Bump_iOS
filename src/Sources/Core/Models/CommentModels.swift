import Foundation

struct CommentDto: Decodable, Identifiable {
    let id: UUID
    let accountId: UUID
    let content: String?
    let images: [ImageDto]
    let reactions: [ReactionDto]
    let reactionAmount: Wrapped<Int>
    let createdAt: Date
}

struct CommentSummaryDto: Decodable, Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    let content: String?
    let images: [ImageDto]
    let reactionAmount: Wrapped<Int>
    let createdAt: Date

    /// Applies an edit locally. `PUT /Comment/{id}` returns no body, so the row is
    /// updated from the text that was sent rather than by refetching the page.
    func withContent(_ content: String) -> CommentSummaryDto {
        CommentSummaryDto(
            id: id,
            accountId: accountId,
            content: content,
            images: images,
            reactionAmount: reactionAmount,
            createdAt: createdAt
        )
    }
}

struct ChangeContentRequest: Encodable {
    let content: String
}
