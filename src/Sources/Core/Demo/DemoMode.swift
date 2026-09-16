#if DEBUG
import Foundation

/// Demo mode: the app running against canned content instead of the live server, so App
/// Store screenshots and previews can be captured from a populated, consistent app.
///
/// **Debug-only by construction.** The whole file is inside `#if DEBUG`, so none of it —
/// not the fixtures, not the protocol, not the fake token — exists in a Release build that
/// could reach the App Store. The demo photographs are not bundled either; they are copied
/// into the simulator's container by the capture script and referenced as `file://` URLs,
/// so the shipping binary carries no extra weight and no third-party imagery.
///
/// Nothing in the app is aware of this beyond two lines in `BumpApp`: the networking is
/// swapped at the one seam the app already had — `APIClient` and `AuthSession` both accept
/// an injected `URLSession` — so every service, store, view model and view runs exactly the
/// code it runs in production, including the real JSON decode path.
enum DemoMode {
    /// Passed by the capture script as a launch argument.
    static let launchArgument = "-BumpDemoMode"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// Capture-only variants: the walkthrough and the signed-out onboarding are part of
    /// the shot list, and demo mode otherwise skips straight past both.
    static var showsIntro: Bool {
        ProcessInfo.processInfo.arguments.contains("-BumpDemoShowIntro")
    }

    static var isSignedOut: Bool {
        ProcessInfo.processInfo.arguments.contains("-BumpDemoSignedOut")
    }

    /// A session whose only protocol is `DemoURLProtocol`, so no request can escape to the
    /// network even by accident.
    ///
    /// `URLProtocol.registerClass` is deliberately *not* used: it does not apply to
    /// `URLSession.shared`, so registering there would silently do nothing and every
    /// request would go to the real server while looking like a fixture bug.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DemoURLProtocol.self]
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    /// An unsigned JWT carrying the two claims `AuthSession.decodeClaims(from:)` reads.
    ///
    /// The client never verifies a signature — it only base64-decodes the payload segment
    /// — so a well-formed three-segment token with the right claim names is enough to put
    /// the app in its signed-in state. The `accountId` must match the viewer in
    /// `DemoContent`, or `MainTabView` renders an empty Profile tab.
    static var accessToken: String {
        let header = base64URL(#"{"alg":"none","typ":"JWT"}"#)
        let payload = base64URL(#"{"accountId":"\#(DemoContent.viewerId.uuidString)","role":"User"}"#)
        return "\(header).\(payload).demo"
    }

    private static func base64URL(_ string: String) -> String {
        Data(string.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Where the capture script drops the demo photographs. Read at runtime rather than
    /// bundled, so nothing ships.
    static var photoDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func photoURL(_ name: String) -> String {
        photoDirectory.appendingPathComponent(name).absoluteString
    }
}
#endif
