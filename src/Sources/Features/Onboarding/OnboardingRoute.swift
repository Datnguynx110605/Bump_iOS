import Foundation

enum OnboardingRoute: Hashable {
    case signUpEmail
    case otpVerify(email: String)
    case createAccount(email: String, registrationToken: String)
    case login
}
