import Foundation

enum APIError: Error, LocalizedError {
    case network(Error)
    case decoding(Error)
    case server(status: Int, message: String)
    case rateLimited(retryAfterSeconds: Int?)
    case unauthenticated

    var errorDescription: String? {
        switch self {
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
