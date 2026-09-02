import Foundation

final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let authSession: AuthSession

    init(baseURL: URL, authSession: AuthSession, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.authSession = authSession
        self.session = session
    }

    func send<Response: Decodable>(_ endpoint: Endpoint) async throws -> Response {
        let (data, http) = try await execute(endpoint)
        try validate(http: http, data: data, endpoint: endpoint)

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        do {
            return try APICoding.decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func execute(_ endpoint: Endpoint) async throws -> (Data, HTTPURLResponse) {
        let token = endpoint.requiresAuth ? await authSession.accessToken : nil
        let request = try buildRequest(endpoint, accessToken: token)
        let (data, http) = try await perform(request)

        guard http.statusCode == 401, endpoint.requiresAuth, !endpoint.isAuthBootstrap else {
            return (data, http)
        }

        do {
            try await authSession.refreshTokens()
        } catch {
            await authSession.signOut()
            throw APIError.unauthenticated
        }

        let retryToken = await authSession.accessToken
        let retryRequest = try buildRequest(endpoint, accessToken: retryToken)
        let (retryData, retryHTTP) = try await perform(retryRequest)

        if retryHTTP.statusCode == 401 {
            await authSession.signOut()
        }
        return (retryData, retryHTTP)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.network(URLError(.badServerResponse))
            }
            return (data, http)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error)
        }
    }

    private func buildRequest(_ endpoint: Endpoint, accessToken: String?) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }
        guard let url = components?.url else {
            throw APIError.network(URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let contentType = endpoint.contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = endpoint.bodyData
        return request
    }

    private func validate(http: HTTPURLResponse, data: Data, endpoint: Endpoint) throws {
        guard !(200..<300).contains(http.statusCode) else { return }

        // A 401 only means "your session expired" for endpoints that actually sent a
        // session token. For unauthenticated endpoints (login, OTP verify, password
        // reset, etc.) a 401 is a normal rejection (e.g. wrong password, expired code)
        // and should fall through to the server's own message below instead.
        if http.statusCode == 401, endpoint.requiresAuth, !endpoint.isAuthBootstrap {
            throw APIError.unauthenticated
        }
        if http.statusCode == 429 {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw APIError.rateLimited(retryAfterSeconds: retryAfter)
        }

        if let problem = try? APICoding.decoder.decode(ProblemDetailsPayload.self, from: data) {
            throw APIError.server(status: http.statusCode, message: problem.userMessage)
        }
        throw APIError.server(status: http.statusCode, message: "Something went wrong (\(http.statusCode)).")
    }
}

extension Array where Element == URLQueryItem {
    static func cursor(_ cursor: String?, pageSize: Int? = nil) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let pageSize { items.append(URLQueryItem(name: "pageSize", value: String(pageSize))) }
        return items
    }
}
