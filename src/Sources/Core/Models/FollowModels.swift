import Foundation

struct FollowerDto: Decodable, Identifiable, Equatable {
    let accountId: UUID
    let name: Wrapped<String>
    let avatar: AvatarDto?
    let followedAt: Date

    var id: UUID { accountId }
}

struct FollowingDto: Decodable, Identifiable, Equatable {
    let accountId: UUID
    let name: Wrapped<String>
    let avatar: AvatarDto?
    let followedAt: Date

    var id: UUID { accountId }
}
