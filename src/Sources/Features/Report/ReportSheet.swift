import SwiftUI

struct ReportSheet: View {
    let target: ReportReasonTarget
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Why are you reporting this?") {
                    TextField("Describe the issue", text: $reason, axis: .vertical)
                        .lineLimit(4...8)
                }
                if let errorMessage {
                    InlineErrorBanner(message: errorMessage)
                        .listRowBackground(Color.clear)
                }
            }
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
                    .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
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
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't submit your report."
        }
    }
}
