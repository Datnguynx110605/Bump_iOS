import Foundation

enum APIError: Error, LocalizedError {
    case network(Error)
    case decoding(Error)
    case server(status: Int, message: String)
    case rateLimited(retryAfterSeconds: Int?)
    case unauthenticated
    /// The app cancelled its own request — a tab switch, a dismissed screen, a
    /// pull-to-refresh the user scrolled away from. Nothing failed, so this case carries
    /// no message and must never reach the screen. See `userMessage(for:)`.
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .network:
            return String(localized: "Couldn't connect. Check your connection and try again.")
        case .decoding:
            return String(localized: "Something went wrong reading the server's response.")
        case .server(_, let message):
            let key = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return Self.friendlyServerMessages[key] ?? message
        case .rateLimited:
            return String(localized: "You're doing that a bit too fast. Try again in a moment.")
        case .unauthenticated:
            return String(localized: "Your session expired. Please log in again.")
        }
    }

    var requiresReauthentication: Bool {
        if case .unauthenticated = self { return true }
        return false
    }

    /// The one place that turns a thrown error into something a screen may show.
    ///
    /// Returns nil for cancellation, which is the whole point: SwiftUI cancels the
    /// `.task` behind a screen the moment it leaves the hierarchy, so switching tabs or
    /// popping a view mid-load used to surface "Couldn't connect. Check your connection"
    /// on a perfectly healthy server — and on an empty list that error takes over the
    /// whole screen. A nil here leaves the banner off and the screen retries on its own.
    static func userMessage(
        for error: Error,
        fallback: @autoclosure () -> String = String(localized: "Something went wrong.")
    ) -> String? {
        guard !error.isCancellation else { return nil }
        return (error as? LocalizedError)?.errorDescription ?? fallback()
    }

    /// Known backend messages that read as engineering internals rather than
    /// something to show a user, mapped to clear, friendly copy. Anything not
    /// in this table is already a clean sentence (verified against the backend)
    /// and is passed through as-is rather than guessed at here.
    private static let friendlyServerMessages: [String: String] = [
        "invalid credentials": String(localized: "Incorrect email or password."),
        "unauthenticated": String(localized: "That code or link has expired. Please try again."),
        "unauthorized": String(localized: "You're not signed in. Please log in and try again."),
        "account not found": String(localized: "We couldn't find an account with that email."),
        "email not found": String(localized: "We couldn't find an account with that email."),
        "email already exists": String(localized: "That email is already registered. Try logging in instead."),
        "otp is incorrect": String(localized: "That code isn't right. Please check and try again."),
        "current password is incorrect": String(localized: "That doesn't match your current password.")
    ]
}

struct EmptyResponse: Decodable {}

struct ProblemDetailsPayload: Decodable {
    let title: String?
    let status: Int?
    let detail: String?
    let errors: [String: [String]]?

    var userMessage: String {
        if let errors, let messages = errors[""], !messages.isEmpty {
            return messages.joined(separator: "\n")
        }
        return detail ?? title ?? String(localized: "Something went wrong.")
    }
}

extension Error {
    /// True when this is the app cancelling its own work rather than a failure worth
    /// reporting. Both spellings occur: structured concurrency throws `CancellationError`,
    /// while a cancelled `URLSessionTask` reports `URLError.cancelled`.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let apiError = self as? APIError, case .cancelled = apiError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
