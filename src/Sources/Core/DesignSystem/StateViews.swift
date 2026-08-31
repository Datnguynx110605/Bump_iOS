import SwiftUI

struct LoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: BumpSpacing.s) {
            Image(systemName: icon)
                .font(.system(.largeTitle))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(BumpSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    var retryTitle: String = String(localized: "Try Again")
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: BumpSpacing.m) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(.largeTitle))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BumpSpacing.l)
            if let onRetry {
                Button(retryTitle, action: onRetry)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FieldHint: View {
    enum Tone {
        case neutral
        case success
        case error
    }

    let text: String
    var tone: Tone = .neutral

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
    }

    private var color: Color {
        switch tone {
        case .neutral: return .secondary
        case .success: return .green
        case .error: return .red
        }
    }
}

struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.red)
            .padding(.horizontal, BumpSpacing.m)
            .padding(.vertical, BumpSpacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: BumpRadius.control))
    }
}
