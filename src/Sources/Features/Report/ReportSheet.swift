import SwiftUI

struct ReportSheet: View {
    let target: ReportReasonTarget
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    /// Mirrors the server's reason validator (non-empty, 2000 max) so an over-length
    /// report is caught here rather than after a round trip.
    private var canSubmit: Bool {
        !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && FreeTextRule.isValid(reason)
            && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Why are you reporting this?") {
                    TextField("Describe the issue", text: $reason, axis: .vertical)
                        .lineLimit(4...8)
                    if let remaining = FreeTextRule.remaining(reason) {
                        FieldHint(
                            text: String(localized: "\(remaining) characters left"),
                            tone: remaining < 0 ? .error : .neutral
                        )
                    }
                }
                if let errorMessage {
                    InlineErrorBanner(message: errorMessage)
                        .listRowBackground(Color.clear)
                }
            }
            .bumpScrollBackground()
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting { ProgressView() } else { Text("Submit") }
                    }
                    .disabled(!canSubmit)
                }
            }
            .alert("Report submitted", isPresented: $didSubmit) {
                Button("OK") { dismiss() }
            } message: {
                Text("Thanks for letting us know. Our team will take a look.")
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await environment.reportService.submit(target: target, reason: reason.trimmingCharacters(in: .whitespacesAndNewlines))
            didSubmit = true
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't submit your report."))
        }
    }
}
