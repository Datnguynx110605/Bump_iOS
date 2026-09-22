import SwiftUI

struct OnboardingFlowView: View {
    @State private var path: [OnboardingRoute] = []
    @State private var showEula = !EulaAcceptance.shared.hasAccepted

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(path: $path)
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .signUpEmail:
                        SignUpEmailView(path: $path)
                    case .otpVerify(let email):
                        OtpVerifyView(path: $path, email: email)
                    case .createAccount(let email, let registrationToken):
                        CreateAccountView(path: $path, email: email, registrationToken: registrationToken)
                    case .login:
                        LoginView(path: $path)
                    case .recoveryEmail(let purpose):
                        RecoveryEmailView(path: $path, purpose: purpose)
                    case .recoveryOtpVerify(let purpose, let email):
                        RecoveryOtpVerifyView(path: $path, purpose: purpose, email: email)
                    case .resetPassword(let email, let registrationToken):
                        ResetPasswordView(path: $path, email: email, registrationToken: registrationToken)
                    case .recoverAccountConfirm(let email, let registrationToken):
                        RecoverAccountConfirmView(path: $path, email: email, registrationToken: registrationToken)
                    }
                }
        }
        // One page background for the whole auth flow: each screen underneath is
        // transparent, so this is what keeps them all on the app's warm surface instead
        // of the system's default white.
        .background(BumpColor.surface)
        // Apple requires acceptance before account creation/login; gate the whole flow.
        .fullScreenCover(isPresented: $showEula) {
            EulaView(onAccept: { showEula = false })
        }
    }
}
