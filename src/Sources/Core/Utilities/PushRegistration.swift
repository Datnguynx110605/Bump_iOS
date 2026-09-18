import SwiftUI
import UserNotifications

/// The app's whole APNs surface: asks for permission, keeps the device token bound to the
/// signed-in account, and presents and routes what arrives.
///
/// A `.shared` singleton, like `LanguagePreference` and `AppearancePreference`, because
/// `AppDelegate` has to reach it and holds no reference to `AppEnvironment`.
@MainActor
final class PushRegistration: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushRegistration()

    /// Handed over by `AppEnvironment.init`. Nil before the app graph is built, which is
    /// also when there is nothing worth uploading.
    var service: NotificationService?
    var authSession: AuthSession?
    var onNotificationTapped: ((AppRoute) -> Void)?

    private var deviceToken: String?

    private override init() {}

    #if DEBUG
    private let isSandbox = true
    #else
    private let isSandbox = false
    #endif

    /// Runs on every sign-in and launch. Re-registering each time is deliberate: APNs can
    /// reissue a token after a restore from backup, an OS upgrade or a reinstall, and the
    /// registration callback is the only place the app is told.
    func start() {
        guard !isDemo else { return }

        if NotificationPreference.isEnabled { requestAuthorizationIfNeeded() }

        UIApplication.shared.registerForRemoteNotifications()

        Task { await sync() }
    }

    func requestAuthorizationIfNeeded() {
        guard !isDemo else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    /// Demo mode runs in the simulator against fixtures: it can never obtain a token, and
    /// the permission prompt would appear over a screenshot capture.
    private var isDemo: Bool {
        #if DEBUG
        return DemoMode.isEnabled
        #else
        return false
        #endif
    }

    func received(token: String) {
        deviceToken = token
        Task { await sync() }
    }

    /// Uploads the token if everything it needs is in place. Called from three places that
    /// arrive in no fixed order — a cold launch restores the session before APNs answers, a
    /// fresh sign-in has the token already — so it is idempotent rather than sequenced.
    func sync() async {
        guard NotificationPreference.isEnabled,
              authSession?.isAuthenticated == true,
              let service,
              let deviceToken else { return }

        // A permission revoked in iOS Settings leaves the token valid and APNs still
        // accepting pushes, which the system then silently discards. Nothing would ever
        // prune that, so check on the way in.
        guard await isAuthorized() else {
            await retire()
            return
        }

        try? await service.registerDevice(token: deviceToken, isSandbox: isSandbox)
    }

    /// Retires the token server-side. Must run *before* the access token is cleared on
    /// sign-out, or the request arrives unauthenticated and the row survives.
    func retire() async {
        guard let service, let deviceToken else { return }

        try? await service.unregisterDevice(token: deviceToken)
    }

    private func isAuthorized() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus != .denied
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// APNs delivers to a foregrounded app too, and this is what draws its banner. It is
    /// the only banner path in the app: the notification a running app shows and the one a
    /// force-quit app shows are the same push.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor [weak self] in
            if let route = AppRoute(pushPayload: userInfo) {
                self?.onNotificationTapped?(route)
            }
            completionHandler()
        }
    }
}
