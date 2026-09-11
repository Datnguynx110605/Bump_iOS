import Foundation

struct ImageDto: Decodable, Equatable, Hashable {
    let url: String
    let uploadedAt: Date
}

struct ReactionDto: Decodable, Identifiable, Equatable {
    let accountId: UUID
    let name: Wrapped<String>
    let avatar: AvatarDto?
    let reactedAt: Date

    var id: UUID { accountId }
}

struct PostDto: Decodable, Identifiable {
    let id: UUID
    let accountId: UUID
    let shopId: UUID
    let images: [ImageDto]
    let caption: String?
    let rate: Wrapped<Int>
    let reactions: [ReactionDto]
    let reactionAmount: Wrapped<Int>
    let commentAmount: Wrapped<Int>
    let createdAt: Date
}

struct PostSummaryDto: Decodable, Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    let shopId: UUID
    let images: [ImageDto]
    let caption: String?
    let rate: Wrapped<Int>
    let reactionAmount: Wrapped<Int>
    let commentAmount: Wrapped<Int>
    let createdAt: Date
}

struct PostFeedItemDto: Decodable, Identifiable, Equatable {
    let post: PostSummaryDto
    let isReacted: Bool
    let isSaved: Bool

    var id: UUID { post.id }
}

struct ChangeCaptionRequest: Encodable {
    let caption: String
}

struct ChangeRateRequest: Encodable {
    let rate: Int
}
