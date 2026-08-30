import Foundation

struct AuthService {
    let api: APIClient

    func login(email: String, password: String) async throws -> AuthTokens {
        try await api.send(.json(
            path: "api/v1/Auth/login",
            method: .post,
            body: LoginRequest(email: email, password: password),
            requiresAuth: false,
            isAuthBootstrap: true
        ))
    }
}

struct EmailService {
    let api: APIClient

    func sendForRegister(email: String) async throws {
        let _: EmptyResponse = try await api.send(.json(
            path: "api/v1/Email/send-for-register", method: .post, body: SendEmailRequest(email: email), requiresAuth: false
        ))
    }

    func sendForVerify(email: String) async throws {
        let _: EmptyResponse = try await api.send(.json(
            path: "api/v1/Email/send-for-verify", method: .post, body: SendEmailRequest(email: email), requiresAuth: false
        ))
    }

    func verify(email: String, otp: String) async throws -> String {
        try await api.send(.json(
            path: "api/v1/Email/verify",
            method: .post,
            body: VerifyEmailRequest(email: email, otp: otp),
            requiresAuth: false
        ))
    }
}
