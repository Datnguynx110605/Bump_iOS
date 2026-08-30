import Foundation

struct NotificationService {
    let api: APIClient

    func mine(cursor: String?, pageSize: Int = 20) async throws -> CursorPage<NotificationSummaryDto> {
        try await api.send(.plain(path: "api/v1/Notification/mine", query: .cursor(cursor, pageSize: pageSize)))
    }
}
