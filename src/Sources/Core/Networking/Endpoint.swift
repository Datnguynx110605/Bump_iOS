import Foundation

struct Endpoint {
    var path: String
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var bodyData: Data?
    var contentType: String?
    var requiresAuth: Bool = true
    var isAuthBootstrap: Bool = false

    static func json<Body: Encodable>(
        path: String,
        method: HTTPMethod,
        body: Body,
        query: [URLQueryItem] = [],
        requiresAuth: Bool = true,
        isAuthBootstrap: Bool = false
    ) throws -> Endpoint {
        Endpoint(
            path: path,
            method: method,
            queryItems: query,
            bodyData: try APICoding.encoder.encode(body),
            contentType: "application/json",
            requiresAuth: requiresAuth,
            isAuthBootstrap: isAuthBootstrap
        )
    }

    static func plain(
        path: String,
        method: HTTPMethod = .get,
        query: [URLQueryItem] = [],
        requiresAuth: Bool = true
    ) -> Endpoint {
        Endpoint(path: path, method: method, queryItems: query, requiresAuth: requiresAuth)
    }

    static func multipart(
        path: String,
        method: HTTPMethod = .post,
        form: MultipartFormData,
        requiresAuth: Bool = true
    ) -> Endpoint {
        Endpoint(
            path: path,
            method: method,
            bodyData: form.finalized(),
            contentType: form.contentType,
            requiresAuth: requiresAuth
        )
    }
}

enum APICoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = DotNetDate.parse(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognized date format: \(string)"
                )
            }
            return date
        }
        return decoder
    }()
}

enum DotNetDate {
    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let withoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        if let date = withFraction.date(from: string) { return date }
        if let date = withoutFraction.date(from: string) { return date }

        guard let dotIndex = string.firstIndex(of: ".") else { return nil }
        let afterDot = string[string.index(after: dotIndex)...]
        guard let boundary = afterDot.firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }) else {
            return nil
        }
        let fraction = String(afterDot[..<boundary].prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
        let normalized = string[..<dotIndex] + "." + fraction + afterDot[boundary...]
        return withFraction.date(from: String(normalized))
    }
}
