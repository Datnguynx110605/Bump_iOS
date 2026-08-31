import UserNotifications

/// Shows an incoming notification as a native iOS banner while the app is running, by
/// scheduling it as a local notification the instant it arrives over the SignalR hub.
/// There's no APNs integration in this app, so this only fires while the process is alive.
@MainActor
enum LocalNotificationScheduler {
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notify(title: String, body: String) {
        guard NotificationPreference.isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
