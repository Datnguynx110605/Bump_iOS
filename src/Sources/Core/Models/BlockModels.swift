import Foundation

struct BlockDto: Decodable, Identifiable, Equatable {
    let accountId: UUID
    let name: Wrapped<String>
    let avatar: AvatarDto?
    let blockedAt: Date

    var id: UUID { accountId }
}
