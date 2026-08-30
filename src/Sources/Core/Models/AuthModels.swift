import Foundation

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct AuthTokens: Decodable {
    let accessToken: String
    let refreshToken: String
}

struct SendEmailRequest: Encodable {
    let email: String
}

struct VerifyEmailRequest: Encodable {
    let email: String
    let otp: String
}
