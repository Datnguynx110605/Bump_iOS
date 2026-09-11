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
    private var topNotificationId: UUID?
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
        topNotificationId = notification.id
    }

    /// The live hub pushes new notifications straight into the list, but only while it is
    /// connected: anything that arrives during a dropped connection, a backgrounded app or
    /// a signed-out socket is missed. This is the catch-up — a single-item probe on every
    /// revisit and tick, reloading only when the newest notification is not the one already
    /// at the top.
    func refreshIfStale() async {
        guard !isLoading else { return }
        guard !notifications.isEmpty else {
            await reload()
            return
        }
        guard let page = try? await notificationService.mine(cursor: nil, pageSize: 1) else { return }
        if page.items.first?.id != topNotificationId { await reload() }
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
            topNotificationId = page.items.first?.id
        } catch {
            errorMessage = APIError.userMessage(for: error)
        }
    }

    func loadMoreIfNeeded(current: NotificationSummaryDto) async {
        guard hasMore, !isLoadingMore, notifications.isNearEnd(current) else { return }
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
