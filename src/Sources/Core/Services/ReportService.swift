import Foundation

struct ReportService {
    let api: APIClient

    func submit(target: ReportReasonTarget, reason: String) async throws -> ReportDto {
        try await api.send(.json(path: "api/v1/Report", method: .post, body: CreateReportRequest(target: target, reason: reason)))
    }
}
