import SwiftUI

// MARK: - Buttons
//
// Four roles, one shape language. Filled and outline actions share the same rounded-rect
// silhouette at `BumpRadius.control` so a primary and a secondary action sitting side by
// side read as the same family at two weights — the difference is fill, never form.
//
// Every style presses the same way: a small scale-down plus a tint shift on a `quick`
// spring. Pressing never changes a control's layout bounds, so nothing around it jumps.

/// Filled accent action — the single most important thing on a screen.
struct BumpPrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            // The label stays in the layout while loading instead of being swapped out,
            // so the button keeps its width and the row it sits in doesn't reflow the
            // moment you tap it.
            configuration.label
                .opacity(isLoading ? 0 : 1)
            if isLoading {
                ProgressView().tint(.white)
            }
        }
        .font(BumpFont.control)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: BumpHitTarget.min)
        .background(BumpColor.brandFill, in: RoundedRectangle(cornerRadius: BumpRadius.control, style: .continuous))
        .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.35)
        .scaleEffect(configuration.isPressed ? 0.975 : 1)
        .bumpAnimation(BumpMotion.quick, value: configuration.isPressed)
        .accessibilityAddTraits(isLoading ? [.updatesFrequently] : [])
    }
}

/// Outline counterpart to `bumpPrimary` — the secondary action beside it (Follow/Following,
/// Edit Profile, retry). No fill at all: on a flat page an outline is the honest way to say
/// "same importance, lower weight" without inventing a second surface colour.
struct BumpSecondaryButtonStyle: ButtonStyle {
    var isProminent: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    private var tint: Color { isProminent ? BumpColor.brand : BumpColor.textPrimary }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BumpFont.control)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: BumpHitTarget.min)
            .padding(.horizontal, BumpSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: BumpRadius.control, style: .continuous)
                    .fill(isProminent ? BumpColor.brandWash : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BumpRadius.control, style: .continuous)
                    .strokeBorder(isProminent ? BumpColor.brandBorder : BumpColor.border, lineWidth: BumpStroke.regular)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .bumpAnimation(BumpMotion.quick, value: configuration.isPressed)
    }
}

/// Bare text action for tertiary navigation ("Forgot password?", "View in Maps").
/// Keeps a full-height hit area so a one-line label is still comfortably tappable.
struct BumpTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BumpFont.control)
            .foregroundStyle(BumpColor.brand)
            .frame(minHeight: BumpHitTarget.min)
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.5 : 1) : 0.35)
            .bumpAnimation(BumpMotion.quick, value: configuration.isPressed)
    }
}

/// Icon-only control (like, save, overflow menu, send). The glyph stays visually small
/// while the tappable region is padded out to `BumpHitTarget.min`, and pressing fades and
/// shrinks rather than moving anything — `.buttonStyle(.plain)` gives neither.
struct BumpIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: BumpHitTarget.min, minHeight: BumpHitTarget.min)
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.45 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .bumpAnimation(BumpMotion.quick, value: configuration.isPressed)
    }
}

/// Whole-row and whole-tile taps (a feed row, a photo in a grid, a search result).
///
/// `.buttonStyle(.plain)` gives a large tappable area with *no* acknowledgement at all,
/// which on a flat, shadowless layout leaves the user unsure the tap registered. This
/// dims and barely shrinks instead — enough to feel, not enough to shove the list around.
struct BumpSurfaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.62 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
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

extension ButtonStyle where Self == BumpSurfaceButtonStyle {
    static var bumpSurface: BumpSurfaceButtonStyle { BumpSurfaceButtonStyle() }
}

// MARK: - Fields

/// A flat tonal well, not an outlined box. On a page with no elevation an inset fill is
/// what makes a field read as *recessed* — the place text goes into — while the 1pt
/// outline stays reserved for buttons, which sit on top of the page rather than in it.
struct BumpTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(BumpFont.body)
            .padding(.horizontal, BumpSpacing.m)
            .padding(.vertical, BumpSpacing.ms)
            .frame(minHeight: BumpHitTarget.min)
            .background(BumpColor.surfaceTertiary, in: RoundedRectangle(cornerRadius: BumpRadius.control, style: .continuous))
    }
}

extension TextFieldStyle where Self == BumpTextFieldStyle {
    static var bump: BumpTextFieldStyle { BumpTextFieldStyle() }
}

// MARK: - Chips

/// Pill-shaped filter/segment control. The one place the system still uses a capsule:
/// a chip is a *token* the user picks up, and the capsule is what distinguishes it at a
/// glance from the rounded-rect buttons that perform actions.
struct BumpChip: View {
    /// A `LocalizedStringKey`, so the title resolves against the `\.locale` the in-app
    /// language switch publishes. Enum `displayName` properties built with
    /// `String(localized:)` resolve against the *process* locale instead and stay English
    /// when the user picks Tiếng Việt — which is why the scopes expose a `titleKey`.
    let title: LocalizedStringKey
    var glyph: BumpGlyph? = nil
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric private var glyphSize: CGFloat = BumpIconSize.xs

    var body: some View {
        Button(action: action) {
            HStack(spacing: BumpSpacing.xs) {
                if let glyph {
                    BumpIcon(glyph, size: glyphSize)
                }
                Text(title)
            }
            .font(BumpFont.control)
            .foregroundStyle(isSelected ? .white : BumpColor.textPrimary)
            .padding(.horizontal, BumpSpacing.m)
            .frame(minHeight: 36)
            .background(isSelected ? AnyShapeStyle(BumpColor.brandFill) : AnyShapeStyle(BumpColor.surfaceTertiary), in: Capsule())
        }
        .buttonStyle(.bumpSurface)
        // A chip row is a set of alternatives, so each chip announces as selected or not
        // rather than as an unrelated button that happens to be tinted.
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .bumpAnimation(BumpMotion.standard, value: isSelected)
    }
}

// MARK: - Structure

/// The 0.5pt rule that separates content on a page with no cards. A plain `Divider()`
/// picks up the system's cool gray, which reads as a cold line across warm paper.
struct BumpDivider: View {
    var inset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(BumpColor.hairline)
            .frame(height: BumpStroke.hairline)
            .padding(.leading, inset)
            .accessibilityHidden(true)
    }
}

/// An editorial section head: uppercase tracked label on the left, optional action on the
/// right. This is what replaces drawing a box around a group of content.
struct BumpSectionHeader<Accessory: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).bumpSectionLabel()
            Spacer(minLength: BumpSpacing.s)
            accessory()
        }
        // The label and its action are separate elements — combining them would make the
        // action unreachable to VoiceOver, which is exactly the bug `EmptyStateView` was
        // fixed for in a previous pass.
        .padding(.horizontal, BumpSpacing.m)
    }
}

extension BumpSectionHeader where Accessory == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.init(title: title) { EmptyView() }
    }
}

// MARK: - Containers

extension View {
    /// An inset tonal block: grouped settings rows, a state message, an inline well.
    ///
    /// Deliberately **flat** — no shadow, no border. Separation comes from the tonal step
    /// against `surface` underneath. This is the modifier that used to draw the app's
    /// floating white card; keeping the name means every call site inherits the new,
    /// grounded treatment without being touched.
    func bumpCard(padding: CGFloat = BumpSpacing.m) -> some View {
        self
            .padding(padding)
            .background(BumpColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: BumpRadius.card, style: .continuous))
    }

    /// The page. Fills the whole screen with `surface` behind whatever it is applied to,
    /// so a short screen and a scrolled one have the same ground.
    func bumpPage() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BumpColor.surface)
    }

    /// Replaces the system grouped background on `List`/`Form` with the app's page
    /// surface, so scrolling containers match plain screens.
    func bumpScrollBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(BumpColor.surface)
    }
}
