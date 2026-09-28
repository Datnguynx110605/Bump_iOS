import SwiftUI

/// Icon + count pairing used for like/comment counters, sized via `@ScaledMetric` so it
/// grows with Dynamic Type. Non-interactive; `BumpToggleIconButton` is the tappable one.
///
/// The count uses monospaced digits (`BumpFont.numeric`) so a like landing on 99 → 100
/// doesn't shove the comment counter next to it sideways mid-animation, and
/// `.contentTransition(.numericText())` rolls the changed digit in place rather than
/// cross-fading the whole number — the two decisions are the same decision, and having
/// the first without the second was why a count could still visibly flicker.
struct ReactionCountLabel: View {
    let glyph: BumpGlyph
    let count: Int
    var isActive = false
    var activeColor: Color = BumpColor.like
    var accessibilityLabel: String?
    @ScaledMetric private var iconSize: CGFloat

    init(
        glyph: BumpGlyph,
        count: Int,
        isActive: Bool = false,
        activeColor: Color = BumpColor.like,
        size: CGFloat = BumpIconSize.medium,
        accessibilityLabel: String? = nil
    ) {
        self.glyph = glyph
        self.count = count
        self.isActive = isActive
        self.activeColor = activeColor
        self.accessibilityLabel = accessibilityLabel
        _iconSize = ScaledMetric(wrappedValue: size)
    }

    var body: some View {
        HStack(spacing: BumpSpacing.xs) {
            BumpIcon(glyph, isActive ? .filled : .outline, size: iconSize)
                .scaleEffect(isActive ? 1.08 : 1)
            if count > 0 {
                Text("\(count)")
                    .font(BumpFont.numeric)
                    .contentTransition(.numericText())
            }
        }
        .foregroundStyle(isActive ? activeColor : BumpColor.textSecondary)
        .bumpAnimation(BumpMotion.bouncy, value: isActive)
        .bumpAnimation(BumpMotion.standard, value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "")
        .accessibilityValue(Text("\(count)"))
    }
}

/// Shared on/off icon control behind every like and save button in the app.
///
/// Centralising it is what gets each of those call sites a 44pt tap target, a pressed
/// state, an accessible name, and the `.isSelected` trait — all of which the hand-rolled
/// `Button { } label: { Image }.buttonStyle(.plain)` version was missing.
///
/// Turning *on* is the moment worth celebrating, so the glyph overshoots on a `bouncy`
/// spring and fires a haptic; turning off just settles back. Asymmetry is the point —
/// bouncing equally in both directions makes un-saving feel like an achievement too.
///
/// The overshoot is a `scaleEffect`, not a symbol effect: the app draws its own glyphs,
/// and `.symbolEffect` only animates SF Symbols. Scaling also keeps the control's layout
/// bounds fixed, so a like landing never nudges the row it sits in.
struct BumpToggleIconButton: View {
    let isOn: Bool
    let glyph: BumpGlyph
    let label: String
    var activeColor: Color = BumpColor.brand
    var size: CGFloat = BumpIconSize.medium
    let action: () -> Void

    @ScaledMetric private var scale: CGFloat = 1

    var body: some View {
        Button {
            if !isOn { HapticFeedback.toggledOn() }
            action()
        } label: {
            BumpIcon(glyph, isOn ? .filled : .outline, size: size * scale)
                .foregroundStyle(isOn ? activeColor : BumpColor.textSecondary)
                .scaleEffect(isOn ? 1.12 : 1)
                .bumpAnimation(BumpMotion.bouncy, value: isOn)
        }
        .buttonStyle(.bumpIcon)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
