import SwiftUI
import UserNotifications

/// Exists for two callbacks SwiftUI's `App` lifecycle has nowhere to receive: the device
/// token APNs hands back, and the failure when it does not.
///
/// The notification-centre delegate is assigned here rather than anywhere in the app graph
/// because iOS requires it to be set before launch finishes. A tap on a push that
/// cold-launched the app — the case this whole feature exists for — is delivered only to a
/// delegate that is already registered.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = PushRegistration.shared
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Hex, not `deviceToken.description`: that renders as `<a1b2 c3d4>`, brackets and
        // spaces included, and APNs rejects it.
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()

        Task { @MainActor in PushRegistration.shared.received(token: token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("APNs registration failed: \(error)")
        #endif
    }
}
