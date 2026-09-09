import SwiftUI

// MARK: - Buttons

/// Filled accent button for the single primary action on a screen.
struct BumpPrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                configuration.label
            }
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: BumpHitTarget.min)
        .background(BumpColor.brandFill, in: RoundedRectangle(cornerRadius: BumpRadius.control, style: .continuous))
        .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
        .scaleEffect(configuration.isPressed ? 0.98 : 1)
        .bumpAnimation(BumpMotion.quick, value: configuration.isPressed)
    }
}

/// Tinted, unfilled counterpart to `bumpPrimary` — for the secondary action beside it
/// (Follow/Following, Edit Profile, retry).
struct BumpSecondaryButtonStyle: ButtonStyle {
    var isProminent: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isProminent ? BumpColor.brand : BumpColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: BumpHitTarget.min)
            .padding(.horizontal, BumpSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: BumpRadius.control, style: .continuous)
                    .fill(isProminent ? BumpColor.brand.opacity(0.12) : BumpColor.surfaceTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BumpRadius.control, style: .continuous)
                    .strokeBorder(isProminent ? BumpColor.brand.opacity(0.35) : BumpColor.border, lineWidth: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .bumpAnimation(BumpMotion.quick, value: configuration.isPressed)
    }
}

/// Bare text button for tertiary navigation ("Forgot password?", "View in Map").
/// Keeps a full-height hit area so a one-line label is still comfortably tappable.
struct BumpTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(BumpColor.brand)
            .frame(minHeight: BumpHitTarget.min)
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.55 : 1) : 0.4)
            .bumpAnimation(BumpMotion.quick, value: configuration.isPressed)
    }
}

/// Icon-only control (like, save, overflow menu, send). The glyph stays visually small
/// while the tappable region is padded out to `BumpHitTarget.min`, and pressing fades
/// rather than moving anything — `.buttonStyle(.plain)` gives neither.
struct BumpIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: BumpHitTarget.min, minHeight: BumpHitTarget.min)
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.5 : 1) : 0.4)
            .bumpAnimation(BumpMotion.quick, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BumpPrimaryButtonStyle {
    static var bumpPrimary: BumpPrimaryButtonStyle { BumpPrimaryButtonStyle() }
    static func bumpPrimary(isLoading: Bool) -> BumpPrimaryButtonStyle { BumpPrimaryButtonStyle(isLoading: isLoading) }
}

extension ButtonStyle where Self == BumpSecondaryButtonStyle {
    static var bumpSecondary: BumpSecondaryButtonStyle { BumpSecondaryButtonStyle() }
    static func bumpSecondary(isProminent: Bool) -> BumpSecondaryButtonStyle { BumpSecondaryButtonStyle(isProminent: isProminent) }
}

extension ButtonStyle where Self == BumpTextButtonStyle {
    static var bumpText: BumpTextButtonStyle { BumpTextButtonStyle() }
}

extension ButtonStyle where Self == BumpIconButtonStyle {
    static var bumpIcon: BumpIconButtonStyle { BumpIconButtonStyle() }
}

// MARK: - Fields

struct BumpTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, BumpSpacing.m)
            .padding(.vertical, BumpSpacing.ms)
            .frame(minHeight: BumpHitTarget.min)
            .background(BumpColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: BumpRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BumpRadius.control, style: .continuous)
                    .strokeBorder(BumpColor.border, lineWidth: 1)
            )
    }
}

extension TextFieldStyle where Self == BumpTextFieldStyle {
    static var bump: BumpTextFieldStyle { BumpTextFieldStyle() }
}

// MARK: - Containers

extension View {
    /// The app's one card treatment: padded, rounded, on `surfaceSecondary`, with the
    /// hairline that keeps it separated from the page in light mode.
    func bumpCard(padding: CGFloat = BumpSpacing.m) -> some View {
        self
            .padding(padding)
            .background(BumpColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: BumpRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BumpRadius.card, style: .continuous)
                    .strokeBorder(BumpColor.border, lineWidth: 1)
            )
    }

    /// Replaces the system grouped background on `List`/`Form` with the app's page
    /// surface, so scrolling containers match plain screens.
    func bumpScrollBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(BumpColor.surface)
    }
}
