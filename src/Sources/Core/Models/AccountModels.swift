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
    /// Whether the server counts this account among the top accounts by follower count
    /// that seed the `trusted` tier of `GET /Post/related`. Carried so the model matches
    /// the wire; nothing renders it yet.
    ///
    /// Optional although the server sends a non-nullable bool, for the same reason
    /// `NotificationSummaryDto` decodes its newer fields leniently: this DTO is the
    /// response of `/Account/me`, `/Account/{id}` and every search page, and a Mongo
    /// inclusion projection that stops naming this field would answer 200 and break all
    /// three at once. Nothing reads it yet, so degrading costs nothing and failing costs
    /// the whole screen.
    let isTrusted: Bool?
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
    let currentPassword: String
}

struct RecoverAccountRequest: Encodable {
    let registrationToken: String
}

struct ResetPasswordRequest: Encodable {
    let registrationToken: String
    let newPassword: String
}
