import Foundation

struct NotificationSummaryDto: Decodable, Identifiable {
    let id: UUID
    let toAccountId: UUID
    let title: String
    let content: String
    let isSent: Bool
    let createdAt: Date
}
