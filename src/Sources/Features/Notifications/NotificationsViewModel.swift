import Foundation

@MainActor
@Observable
final class NotificationsViewModel {
    var notifications: [NotificationSummaryDto] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    private var nextCursor: String?
    private var hasMore = true
    private let notificationService: NotificationService

    init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }

    func loadInitialIfNeeded() async {
        guard notifications.isEmpty else { return }
        await reload()
    }

    func prepend(_ notification: NotificationSummaryDto) {
        guard !notifications.contains(where: { $0.id == notification.id }) else { return }
        notifications.insert(notification, at: 0)
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await notificationService.mine(cursor: nil)
            notifications = page.items
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(localized: "Something went wrong.")
        }
    }

    func loadMoreIfNeeded(current: NotificationSummaryDto) async {
        guard hasMore, !isLoadingMore, notifications.last?.id == current.id else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await notificationService.mine(cursor: nextCursor)
            notifications.append(contentsOf: page.items)
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
        }
    }
}
