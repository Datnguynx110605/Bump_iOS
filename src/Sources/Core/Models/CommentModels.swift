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
}
