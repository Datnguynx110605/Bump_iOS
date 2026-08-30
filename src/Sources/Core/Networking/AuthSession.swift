import Foundation
import Observation

private struct RefreshRequestBody: Encodable {
    let refreshToken: String
}

private struct AuthTokensResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

@MainActor
@Observable
final class AuthSession {
    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var accountId: UUID?
    private(set) var role: String?

    var isAuthenticated: Bool { accessToken != nil }
    var isAdmin: Bool { role == "Admin" }

    private let baseURL: URL
    private let tokenStore: KeychainTokenStore
    private let session: URLSession
    private var inFlightRefresh: Task<Void, Error>?

    init(baseURL: URL, tokenStore: KeychainTokenStore = KeychainTokenStore(), session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session
        if let stored = tokenStore.load() {
            accessToken = stored.accessToken
            refreshToken = stored.refreshToken
            decodeClaims(from: stored.accessToken)
        }
    }

    func setTokens(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        decodeClaims(from: accessToken)
        tokenStore.save(StoredTokens(accessToken: accessToken, refreshToken: refreshToken))
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        accountId = nil
        role = nil
        tokenStore.clear()
    }

    func refreshTokens() async throws {
        if let inFlightRefresh {
            try await inFlightRefresh.value
            return
        }
        let task = Task { try await performRefresh() }
        inFlightRefresh = task
        defer { inFlightRefresh = nil }
        try await task.value
    }

    private func performRefresh() async throws {
        guard let refreshToken else {
            signOut()
            throw APIError.unauthenticated
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/Auth/refresh"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try APICoding.encoder.encode(RefreshRequestBody(refreshToken: refreshToken))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            signOut()
            throw APIError.unauthenticated
        }

        let tokens = try APICoding.decoder.decode(AuthTokensResponse.self, from: data)
        setTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
    }

    private func decodeClaims(from jwt: String) {
        let segments = jwt.split(separator: ".")
        guard segments.count >= 2 else { return }

        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let idString = json["accountId"] as? String, let id = UUID(uuidString: idString) {
            accountId = id
        }
        role = json["role"] as? String
    }
}
