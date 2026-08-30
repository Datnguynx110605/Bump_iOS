import Foundation

enum ReportReasonTarget {
    case post(UUID)
    case comment(UUID)
    case account(UUID)
}

struct CreateReportRequest: Encodable {
    let postId: UUID?
    let commentId: UUID?
    let accountId: UUID?
    let reason: String

    init(target: ReportReasonTarget, reason: String) {
        switch target {
        case .post(let id):
            postId = id; commentId = nil; accountId = nil
        case .comment(let id):
            postId = nil; commentId = id; accountId = nil
        case .account(let id):
            postId = nil; commentId = nil; accountId = id
        }
        self.reason = reason
    }
}

struct ReportDto: Decodable, Identifiable {
    let id: UUID
    let reporterId: UUID
    let postId: UUID?
    let commentId: UUID?
    let accountId: UUID?
    let reason: String
    let createdAt: Date
}
