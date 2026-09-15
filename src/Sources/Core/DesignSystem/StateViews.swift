import SwiftUI

struct LoadingView: View {
    var body: some View {
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BumpColor.surface)
            .accessibilityLabel(String(localized: "Loading"))
    }
}

/// Shared empty state. The icon sits in a soft accent disc so an empty screen still
/// reads as designed rather than broken, and the title/message pair is one accessibility
/// element so VoiceOver announces it as a single message.
///
/// The combine stops at the text. Applied to the whole stack — as it was — it absorbed
/// the action button into the same element, and an absorbed button is not focusable, so
/// `HomeView`'s "Discover Shops & People" was the one way off an empty feed and VoiceOver
/// could not reach it. `ErrorStateView` below has the same shape and never combined.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @ScaledMetric private var iconSize: CGFloat = BumpIconSize.large
    @ScaledMetric private var discSize: CGFloat = 72

    var body: some View {
        VStack(spacing: BumpSpacing.ms) {
            Circle()
                .fill(BumpColor.brand.opacity(0.12))
                .frame(width: discSize, height: discSize)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: iconSize))
                        .foregroundStyle(BumpColor.brand)
                }
                .accessibilityHidden(true)

            VStack(spacing: BumpSpacing.xs) {
                Text(title)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .foregroundStyle(BumpColor.textPrimary)
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(BumpColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .accessibilityElement(children: .combine)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bumpSecondary(isProminent: true))
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.top, BumpSpacing.xs)
            }
        }
        .padding(BumpSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BumpColor.surface)
    }
}

/// Failure state. Same shape as `EmptyStateView` so a failed load and an empty result
/// don't look like two unrelated screens, but tinted with `danger` and always offering
/// a retry.
struct ErrorStateView: View {
    let message: String
    var retryTitle: String = String(localized: "Try Again")
    var onRetry: (() -> Void)? = nil

    @ScaledMetric private var iconSize: CGFloat = BumpIconSize.large
    @ScaledMetric private var discSize: CGFloat = 72

    var body: some View {
        VStack(spacing: BumpSpacing.ms) {
            Circle()
                .fill(BumpColor.danger.opacity(0.12))
                .frame(width: discSize, height: discSize)
                .overlay {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: iconSize))
                        .foregroundStyle(BumpColor.danger)
                }
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(BumpColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BumpSpacing.l)

            if let onRetry {
                Button(retryTitle, action: onRetry)
                    .buttonStyle(.bumpSecondary(isProminent: true))
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.top, BumpSpacing.xs)
            }
        }
        .padding(BumpSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BumpColor.surface)
    }
}

/// Inline validation text under a field. Pairs an icon with the color so the tone isn't
/// carried by color alone.
struct FieldHint: View {
    enum Tone {
        case neutral
        case success
        case error
    }

    let text: String
    var tone: Tone = .neutral

    var body: some View {
        Label {
            Text(text)
        } icon: {
            if let icon {
                Image(systemName: icon)
            }
        }
        .font(.caption)
        .foregroundStyle(color)
        .padding(.horizontal, BumpSpacing.xs)
    }

    private var icon: String? {
        switch tone {
        case .neutral: return nil
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    private var color: Color {
        switch tone {
        case .neutral: return BumpColor.textSecondary
        case .success: return BumpColor.success
        case .error: return BumpColor.danger
        }
    }
}

struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(BumpColor.danger)
            .padding(.horizontal, BumpSpacing.m)
            .padding(.vertical, BumpSpacing.ms)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BumpColor.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: BumpRadius.control, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}
