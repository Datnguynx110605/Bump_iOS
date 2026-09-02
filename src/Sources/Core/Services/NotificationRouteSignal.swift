import Foundation

@MainActor
@Observable
final class NotificationRouteSignal {
    private(set) var pendingRoute: AppRoute?

    func open(_ route: AppRoute) {
        pendingRoute = route
    }

    func clear() {
        pendingRoute = nil
    }
}
