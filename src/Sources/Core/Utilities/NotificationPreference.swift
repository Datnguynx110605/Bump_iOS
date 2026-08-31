import Foundation

/// Backs the Settings "Notifications" toggle. A plain `UserDefaults` read (rather than
/// `@AppStorage`, which only works inside a View) so `NotificationHubClient` can check it too.
enum NotificationPreference {
    static let key = "notificationsEnabled"

    static var isEnabled: Bool {
        (UserDefaults.standard.object(forKey: key) as? Bool) ?? true
    }
}
