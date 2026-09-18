import Foundation

struct NotificationService {
    let api: APIClient

    func mine(cursor: String?, pageSize: Int = 20) async throws -> CursorPage<NotificationSummaryDto> {
        try await api.send(.plain(path: "api/v1/Notification/mine", query: .cursor(cursor, pageSize: pageSize)))
    }

    func registerDevice(token: String, isSandbox: Bool) async throws {
        let _: EmptyResponse = try await api.send(.json(
            path: "api/v1/Notification/device",
            method: .post,
            body: RegisterDeviceRequest(token: token, isSandbox: isSandbox)))
    }

    func unregisterDevice(token: String) async throws {
        let _: EmptyResponse = try await api.send(
            .plain(path: "api/v1/Notification/device/\(token)", method: .delete))
    }
}

struct RegisterDeviceRequest: Encodable {
    let token: String
    let isSandbox: Bool
}
