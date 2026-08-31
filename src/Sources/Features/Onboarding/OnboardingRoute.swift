import Foundation

enum OnboardingRoute: Hashable {
    case signUpEmail
    case otpVerify(email: String)
    case createAccount(email: String, registrationToken: String)
    case login
    case recoveryEmail(purpose: RecoveryPurpose)
    case recoveryOtpVerify(purpose: RecoveryPurpose, email: String)
    case resetPassword(email: String, registrationToken: String)
    case recoverAccountConfirm(email: String, registrationToken: String)
}

enum RecoveryPurpose: Hashable {
    case forgotPassword
    case recoverAccount

    var emailTitle: String {
        switch self {
        case .forgotPassword: return String(localized: "Reset your password")
        case .recoverAccount: return String(localized: "Recover your account")
        }
    }

    var emailSubtitle: String {
        switch self {
        case .forgotPassword: return String(localized: "Enter the email on your account and we'll send you a 6-digit code.")
        case .recoverAccount: return String(localized: "Enter the email of the account you'd like to recover and we'll send you a 6-digit code.")
        }
    }
}
