import Foundation

struct AvatarDto: Decodable, Equatable, Hashable {
    let url: String
    let createdAt: Date
}

struct AccountDto: Decodable, Identifiable {
    let id: UUID
    let email: Wrapped<String>
    let name: Wrapped<String>
    let avatars: [AvatarDto]
    let bio: String?
    let followerAmount: Wrapped<Int>
    let followingAmount: Wrapped<Int>
    let createdAt: Date
}

struct AccountSummaryDto: Decodable, Identifiable, Equatable {
    let id: UUID
    let name: Wrapped<String>
    let avatar: AvatarDto?
    let bio: String?
    let followerAmount: Wrapped<Int>
    let followingAmount: Wrapped<Int>
}

struct CreateAccountRequest: Encodable {
    let registrationToken: String
    let name: String
    let password: String
    let bio: String?
}

struct ChangeNameRequest: Encodable {
    let name: String
}

struct ChangeBioRequest: Encodable {
    let bio: String?
}

struct ChangePasswordRequest: Encodable {
    let currentPassword: String
    let newPassword: String
}

struct ChangeEmailRequest: Encodable {
    let registrationToken: String
}
