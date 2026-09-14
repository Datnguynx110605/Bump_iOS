import SwiftUI

struct RecoveryOtpVerifyView: View {
    @Binding var path: [OnboardingRoute]
    let purpose: RecoveryPurpose
    let email: String
    @Environment(AppEnvironment.self) private var environment

    @State private var otp = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resendCooldown = 0
    @State private var resendTimer: Timer?
    @FocusState private var isFocused: Bool

    private var isValid: Bool { otp.count == 6 }

    var body: some View {
        AuthFormLayout {
            VStack(alignment: .leading, spacing: BumpSpacing.s) {
                Text("Enter your code")
                    .font(.largeTitle.bold())
                Text("We sent a 6-digit code to \(email).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, BumpSpacing.l)

            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                TextField("000000", text: $otp)
                    .textFieldStyle(.bump)
                    .font(.system(.title, design: .monospaced, weight: .semibold))
                    .kerning(6)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    // Lets iOS surface the emailed code above the keyboard instead of
                    // making the user transcribe six digits by hand (WCAG 2.2 AA,
                    // Accessible Authentication).
                    .textContentType(.oneTimeCode)
                    .focused($isFocused)
                    .onChange(of: otp) { _, newValue in
                        otp = String(newValue.filter(\.isNumber).prefix(6))
                    }
                if !otp.isEmpty && !isValid {
                    FieldHint(text: String(localized: "Enter all 6 digits (\(otp.count)/6)."), tone: .neutral)
                }
            }

            if let errorMessage {
                InlineErrorBanner(message: errorMessage)
            }

            Button {
                Task { await resend() }
            } label: {
                Text(resendCooldown > 0 ? "Resend code (\(resendCooldown)s)" : "Resend code")
            }
            .buttonStyle(.bumpText)
            .disabled(resendCooldown > 0)
        } action: {
            Button {
                Task { await verify() }
            } label: {
                Text("Verify")
            }
            .buttonStyle(.bumpPrimary(isLoading: isLoading))
            .disabled(!isValid || isLoading)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isFocused = true
            startCooldown()
        }
        .onDisappear { resendTimer?.invalidate() }
    }

    private func verify() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let registrationToken = try await environment.emailService.verify(email: email, otp: otp)
            switch purpose {
            case .forgotPassword:
                path.append(.resetPassword(email: email, registrationToken: registrationToken))
            case .recoverAccount:
                path.append(.recoverAccountConfirm(email: email, registrationToken: registrationToken))
            }
        } catch {
            errorMessage = APIError.userMessage(for: error)
        }
    }

    private func resend() async {
        errorMessage = nil
        do {
            try await environment.emailService.sendForVerify(email: email)
            startCooldown()
        } catch {
            errorMessage = APIError.userMessage(for: error)
        }
    }

    private func startCooldown() {
        resendCooldown = 60
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if resendCooldown > 0 {
                    resendCooldown -= 1
                } else {
                    resendTimer?.invalidate()
                }
            }
        }
    }
}
