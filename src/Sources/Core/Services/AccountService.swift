import Foundation

struct AccountService {
    let api: APIClient

    func create(registrationToken: String, name: String, password: String, bio: String?) async throws -> AccountDto {
        try await api.send(.json(
            path: "api/v1/Account",
            method: .post,
            body: CreateAccountRequest(registrationToken: registrationToken, name: name, password: password, bio: bio),
            requiresAuth: false
        ))
    }

    func me() async throws -> AccountSummaryDto {
        try await api.send(.plain(path: "api/v1/Account/me"))
    }

    func account(id: UUID) async throws -> AccountSummaryDto {
        try await api.send(.plain(path: "api/v1/Account/\(id)"))
    }

    func changeName(_ name: String) async throws {
        let _: EmptyResponse = try await api.send(.json(
            path: "api/v1/Account/me/name", method: .put, body: ChangeNameRequest(name: name)
        ))
    }

    func changeBio(_ bio: String?) async throws {
        let _: EmptyResponse = try await api.send(.json(
            path: "api/v1/Account/me/bio", method: .put, body: ChangeBioRequest(bio: bio)
        ))
    }

    /// Answers a fresh token pair rather than nothing: the server revokes every refresh
    /// token on the account, so the caller's own session has to be replaced with what
    /// comes back or it dies the next time the access token expires.
    func changePassword(current: String, new: String) async throws -> AuthTokens {
        try await api.send(.json(
            path: "api/v1/Account/me/password",
            method: .put,
            body: ChangePasswordRequest(currentPassword: current, newPassword: new)
        ))
    }

    func changeEmail(registrationToken: String, currentPassword: String) async throws {
        let _: EmptyResponse = try await api.send(.json(
            path: "api/v1/Account/me/email",
            method: .put,
            body: ChangeEmailRequest(registrationToken: registrationToken, currentPassword: currentPassword)
        ))
    }

    func recoverAccount(registrationToken: String) async throws {
        let _: EmptyResponse = try await api.send(.json(
            path: "api/v1/Account/recover",
            method: .post,
            body: RecoverAccountRequest(registrationToken: registrationToken),
            requiresAuth: false
        ))
    }

    func resetPassword(registrationToken: String, newPassword: String) async throws {
        let _: EmptyResponse = try await api.send(.json(
            path: "api/v1/Account/reset-password",
            method: .put,
            body: ResetPasswordRequest(registrationToken: registrationToken, newPassword: newPassword),
            requiresAuth: false
        ))
    }

    func changeAvatar(_ image: ImageUpload) async throws {
        var form = MultipartFormData()
        form.addFile(name: "avatar", filename: image.filename, mimeType: image.mimeType, fileData: image.data)
        let _: EmptyResponse = try await api.send(.multipart(path: "api/v1/Account/me/avatar", form: form))
    }

    /// The url names which avatar to drop: the account keeps a history of them, so the
    /// server needs the one being removed rather than "the current one".
    func removeAvatar(url: String) async throws {
        let _: EmptyResponse = try await api.send(.plain(
            path: "api/v1/Account/me/avatar",
            method: .delete,
            query: [URLQueryItem(name: "url", value: url)]
        ))
    }

    func deleteAccount() async throws {
        let _: EmptyResponse = try await api.send(.plain(path: "api/v1/Account/me", method: .delete))
    }

    func searchByKeyword(_ keyword: String, cursor: String?, pageSize: Int = 20) async throws -> CursorPage<AccountSummaryDto> {
        try await api.send(.plain(
            path: "api/v1/Account/search",
            query: [URLQueryItem(name: "keyword", value: keyword)] + .cursor(cursor, pageSize: pageSize)
        ))
    }
}
