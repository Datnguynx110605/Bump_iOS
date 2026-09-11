import SwiftUI

private enum ChangeEmailStep {
    case enterEmail
    case enterOtp
}

struct ChangeEmailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var step: ChangeEmailStep = .enterEmail
    @State private var email = ""
    @State private var otp = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didSave = false

    var body: some View {
        Form {
            switch step {
            case .enterEmail:
                Section {
                    TextField("New email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    if !email.isEmpty && !EmailRule.isValid(email) {
                        Text("Enter a valid email address.").foregroundStyle(BumpColor.danger)
                    } else {
                        Text("The address must already have an account with Bump — this flow moves your login to an existing address, it can't register a brand-new one.")
                    }
                }
            case .enterOtp:
                Section {
                    TextField("6-digit code", text: $otp)
                        .keyboardType(.numberPad)
                        // Same reason as the onboarding OTP fields: let iOS offer the
                        // code rather than requiring manual transcription.
                        .textContentType(.oneTimeCode)
                        .onChange(of: otp) { _, newValue in
                            otp = String(newValue.filter(\.isNumber).prefix(6))
                        }
                } footer: {
                    if !otp.isEmpty && otp.count < 6 {
                        Text("Enter all 6 digits (\(otp.count)/6).")
                    } else {
                        Text("We sent a code to \(email).")
                    }
                }
            }

            if let errorMessage {
                InlineErrorBanner(message: errorMessage)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BumpColor.surface)
        .navigationTitle("Change Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await primaryAction() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(step == .enterEmail ? "Send Code" : "Verify")
                    }
                }
                .disabled(!isPrimaryActionEnabled || isLoading)
            }
        }
        .alert("Email Updated", isPresented: $didSave) {
            Button("OK") { dismiss() }
        }
    }

    private var isPrimaryActionEnabled: Bool {
        switch step {
        case .enterEmail: return EmailRule.isValid(email)
        case .enterOtp: return otp.count == 6
        }
    }

    private func primaryAction() async {
        switch step {
        case .enterEmail: await sendCode()
        case .enterOtp: await verifyAndSave()
        }
    }

    private func sendCode() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await environment.emailService.sendForVerify(email: email)
            step = .enterOtp
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't send the code."))
        }
    }

    private func verifyAndSave() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let registrationToken = try await environment.emailService.verify(email: email, otp: otp)
            try await environment.accountService.changeEmail(registrationToken: registrationToken)
            didSave = true
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't update your email."))
        }
    }
}

extension ChangeEmailStep: Equatable {}
