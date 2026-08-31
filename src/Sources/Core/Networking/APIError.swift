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
            return message
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
