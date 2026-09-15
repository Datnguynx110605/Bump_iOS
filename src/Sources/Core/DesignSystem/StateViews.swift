import SwiftUI

/// Indeterminate spinner for a screen that has nothing to show yet and no shape to
/// predict. Where the shape *is* predictable — a feed, a list of people — use
/// `BumpSkeletonList` instead: showing the layout that is coming makes the wait feel
/// shorter than a spinner does, and it stops the screen from jumping when content lands.
struct LoadingView: View {
    var body: some View {
        ProgressView()
            .controlSize(.large)
            .tint(BumpColor.brand)
            .bumpPage()
            .accessibilityLabel(String(localized: "Loading"))
    }
}

/// A placeholder in the shape of the content that's loading, breathing gently so the
/// screen reads as *working* rather than broken.
///
/// The pulse is opacity only — no offset, no gradient sweep — so it costs one animatable
/// property per block and can't shift layout. Reduce Motion stops the breathing and
/// leaves the blocks at rest, which is the whole point of the setting: the information
/// ("something is coming, and this is its shape") survives, the movement doesn't.
struct BumpSkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = BumpRadius.small

    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(BumpColor.fill)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .opacity(isPulsing ? 0.55 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

/// Feed-shaped skeleton: author line, square photo, action row. Mirrors `PostRowView`'s
/// proportions so content landing doesn't visibly re-lay-out the screen.
struct BumpSkeletonList: View {
    var count: Int = 3

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                VStack(alignment: .leading, spacing: BumpSpacing.ms) {
                    HStack(spacing: BumpSpacing.s) {
                        Circle().fill(BumpColor.fill).frame(width: 36, height: 36)
                        BumpSkeletonBlock(width: 120, height: 12)
                    }
                    .padding(.horizontal, BumpSpacing.m)

                    // A bare `Rectangle`, not `BumpSkeletonBlock`: that component pins an
                    // explicit height, which wins over an outer `aspectRatio` and collapses
                    // the photo to nothing — leaving a "feed skeleton" with no photo in it.
                    Rectangle()
                        .fill(BumpColor.fill)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: BumpSpacing.s) {
                        BumpSkeletonBlock(width: 160, height: 12)
                        BumpSkeletonBlock(height: 12)
                    }
                    .padding(.horizontal, BumpSpacing.m)
                }
                .padding(.vertical, BumpSpacing.m)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Loading"))
    }
}

/// List-of-people skeleton: avatar plus a name line, at the same row height the real rows
/// use, so followers/reactors screens don't jump when the page lands.
struct PeopleSkeletonList: View {
    var count: Int = 8

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: BumpSpacing.ms) {
                    Circle().fill(BumpColor.fill).frame(width: 44, height: 44)
                    BumpSkeletonBlock(width: 150, height: 12)
                    Spacer()
                }
                .padding(.horizontal, BumpSpacing.m)
                .padding(.vertical, BumpSpacing.ms)
            }
            Spacer()
        }
        .bumpPage()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Loading"))
    }
}

/// Shared empty state.
///
/// No tinted disc behind the glyph any more — on a flat page a filled circle is another
/// floating object. The icon is drawn large and light in the brand tint instead, so the
/// weight in the composition comes from type and scale rather than from a container.
///
/// The title/message pair is one accessibility element so VoiceOver announces it as a
/// single message. **The combine stops at the text.** Applied to the whole stack — as it
/// once was — it absorbed the action button into the same element, and an absorbed button
/// is not focusable, so `HomeView`'s discovery action was the one way off an empty feed
/// and VoiceOver could not reach it.
struct EmptyStateView: View {
    let icon: String
    /// `LocalizedStringKey`, **not** a pre-resolved `String`.
    ///
    /// `String(localized:)` resolves against the process locale, which the app's in-app
    /// language switch cannot change — `LanguagePreference` publishes its choice through
    /// `.environment(\.locale,)`, and only `LocalizedStringKey` reads that. Passing
    /// already-resolved text here is why every empty state stayed in English after
    /// switching the app to Tiếng Việt while the navigation titles beside them translated.
    let title: LocalizedStringKey
    var message: LocalizedStringKey? = nil
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    @ScaledMetric private var iconSize: CGFloat = BumpIconSize.hero

    var body: some View {
        VStack(spacing: BumpSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .light))
                .foregroundStyle(BumpColor.brand.opacity(0.65))
                .accessibilityHidden(true)

            VStack(spacing: BumpSpacing.s) {
                Text(title)
                    .font(BumpFont.title)
                    .foregroundStyle(BumpColor.textPrimary)
                    .multilineTextAlignment(.center)
                if let message {
                    Text(message)
                        .font(BumpFont.callout)
                        .foregroundStyle(BumpColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
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
        .padding(.horizontal, BumpSpacing.xl)
        .padding(.vertical, BumpSpacing.l)
        .bumpPage()
    }
}

/// Failure state. Same composition as `EmptyStateView` so a failed load and an empty
/// result don't look like two unrelated screens, but tinted with `danger` and always
/// offering a retry.
struct ErrorStateView: View {
    /// Stays a plain `String`: this carries runtime text from
    /// `APIError.userMessage(for:)`, which is already resolved and is not a catalogue key.
    let message: String
    var retryTitle: LocalizedStringKey = "Try again"
    var onRetry: (() -> Void)? = nil

    @ScaledMetric private var iconSize: CGFloat = BumpIconSize.hero

    var body: some View {
        VStack(spacing: BumpSpacing.m) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: iconSize, weight: .light))
                .foregroundStyle(BumpColor.danger.opacity(0.75))
                .accessibilityHidden(true)

            // One message, not two. `APIError.userMessage(for:)` already returns a
            // complete, friendly sentence ("Couldn't connect. Check your connection and
            // try again."), so a hardcoded headline above it stacks two apologies and
            // says less than either one alone.
            Text(message)
                .font(BumpFont.headline)
                .foregroundStyle(BumpColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            if let onRetry {
                Button(retryTitle, action: onRetry)
                    .buttonStyle(.bumpSecondary(isProminent: true))
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.top, BumpSpacing.xs)
            }
        }
        .padding(.horizontal, BumpSpacing.xl)
        .padding(.vertical, BumpSpacing.l)
        .bumpPage()
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

    /// A key, for the same reason `EmptyStateView.title` is one: hint copy is literal UI
    /// text and must resolve against the in-app `\.locale`, not the process locale.
    let text: LocalizedStringKey
    var tone: Tone = .neutral

    var body: some View {
        Label {
            Text(text)
        } icon: {
            if let icon {
                Image(systemName: icon)
            }
        }
        .font(.system(.caption, design: .rounded, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, BumpSpacing.xs)
        .bumpAnimation(BumpMotion.quick, value: tone)
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

/// Form-level failure, shown above the action that failed. A tonal danger wash rather
/// than an outlined box — consistent with the rule that outlines mean "tappable".
struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.system(.footnote, design: .rounded, weight: .medium))
            .foregroundStyle(BumpColor.danger)
            .padding(.horizontal, BumpSpacing.m)
            .padding(.vertical, BumpSpacing.ms)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BumpColor.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: BumpRadius.control, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}
