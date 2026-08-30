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

    func changePassword(current: String, new: String) async throws {
        let _: EmptyResponse = try await api.send(.json(
            path: "api/v1/Account/me/password",
            method: .put,
            body: ChangePasswordRequest(currentPassword: current, newPassword: new)
        ))
    }

    func changeEmail(registrationToken: String) async throws {
        let _: EmptyResponse = try await api.send(.json(
            path: "api/v1/Account/me/email", method: .put, body: ChangeEmailRequest(registrationToken: registrationToken)
        ))
    }

    func changeAvatar(_ image: ImageUpload) async throws {
        var form = MultipartFormData()
        form.addFile(name: "avatar", filename: image.filename, mimeType: image.mimeType, fileData: image.data)
        let _: EmptyResponse = try await api.send(.multipart(path: "api/v1/Account/me/avatar", form: form))
    }

    func removeAvatar(url: String) async throws {
        let _: EmptyResponse = try await api.send(.plain(
            path: "api/v1/Account/me/avatar", method: .delete, query: [URLQueryItem(name: "url", value: url)]
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
