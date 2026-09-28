import SwiftUI
import UIKit

// MARK: - Design language
//
// Bump's visual system is **editorial full-bleed**: the app has no floating cards, no
// drop shadows, and no translucency. Content sits directly on one continuous warm page,
// photos bleed to the screen edges, and separation is carried by hairlines and vertical
// rhythm rather than by elevation.
//
// Three rules hold the whole system together:
//
// 1. **One page, one surface.** `BumpColor.surface` is the background of every screen.
//    Anything that needs to read as a distinct block uses a *tonal* step
//    (`surfaceSecondary` / `surfaceTertiary`), never a shadow.
// 2. **Hairlines, not borders.** A 0.5pt `hairline` divides content. A 1pt stroke is
//    reserved for interactive outlines (a field, an outline button) so a boundary you can
//    touch always looks heavier than one you can't.
// 3. **Type carries hierarchy.** `BumpFont` is the scale. An uppercase tracked `label`
//    heads a section; a bold `title` opens a screen. Nothing relies on a box to say
//    "this is important".

/// 4pt rhythm. Every gap, inset, and section break in the app comes from here so
/// vertical spacing stays on the same grid across screens.
enum BumpSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    /// Control-internal padding (field/button vertical inset). Sits between `s` and `m`
    /// because 8 is too tight for a 44pt touch target and 16 overshoots it.
    static let ms: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

/// Corner language. Editorial content is **square** — a full-bleed photo has radius 0 and
/// is clipped by the screen, not by a card. Radii exist only for things you touch
/// (controls, chips, wells) and for inset blocks that are deliberately *not* full-bleed.
enum BumpRadius {
    /// Thumbnails, inline image wells, small tiles.
    static let small: CGFloat = 8
    /// Text fields, tonal wells, inset blocks.
    static let control: CGFloat = 14
    /// Grouped blocks that sit inset from the page edge (settings groups, state blocks).
    static let card: CGFloat = 20
}

/// Stroke weights. The split is semantic, not decorative: `hairline` separates content,
/// `regular` outlines something tappable. Keeping them different is what stops a divider
/// from reading as a button edge.
enum BumpStroke {
    static let hairline: CGFloat = 0.5
    static let regular: CGFloat = 1
}

/// Extra leading for running prose, on top of what the text style already carries.
///
/// One value, not a scale. The app had five different hand-picked numbers, and two of
/// them were on *the same post caption* — 1pt in the feed row, 3pt on the post detail —
/// so the same sentence set differently depending on where you read it. Density between
/// those two screens is carried by the feed's 3-line clamp, which is a limit on how much
/// text shows rather than a reason to re-space it.
enum BumpLeading {
    static let prose: CGFloat = 2
}

/// Apple's minimum comfortable tap area. Icon-only controls are visually smaller than
/// this, so they expand their hit region to it rather than growing the glyph.
enum BumpHitTarget {
    static let min: CGFloat = 44
}

extension Color {
    /// A dynamic color that swaps by appearance, so a single token can commit to a
    /// specific light palette while overriding what dark mode uses (e.g. a warm espresso
    /// instead of the system's default elevated dark grays).
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/// Semantic colors layered on top of system colors so every screen stays consistent and
/// adapts automatically to light/dark mode.
///
/// Light mode is a warm, off-white paper tone. Dark mode mirrors that warmth with a deep
/// espresso instead of the system's elevated grays: never a true, cold black, but still
/// dark enough for comfortable night use.
///
/// The palette values are unchanged from the previous system — what changed is how they
/// are *used*. `surface` is now the background of every screen rather than the gap
/// between cards, and `surfaceSecondary` has become the tonal step for inset blocks.
enum BumpColor {
    /// The page. Every screen's background, edge to edge, top to bottom.
    static let surface = Color.adaptive(light: UIColor(red: 0.980, green: 0.961, blue: 0.929, alpha: 1), dark: UIColor(red: 0.109, green: 0.082, blue: 0.071, alpha: 1))
    /// One tonal step up from the page: inset blocks, grouped rows, sheets.
    static let surfaceSecondary = Color.adaptive(light: .white, dark: UIColor(red: 0.165, green: 0.125, blue: 0.098, alpha: 1))
    /// Two steps up: wells, chips, composer bars, selected rows.
    static let surfaceTertiary = Color.adaptive(light: UIColor(red: 0.945, green: 0.914, blue: 0.867, alpha: 1), dark: UIColor(red: 0.200, green: 0.157, blue: 0.129, alpha: 1))
    /// Neutral placeholder block behind images that haven't decoded yet.
    static let fill = Color.adaptive(light: UIColor(red: 0.914, green: 0.875, blue: 0.820, alpha: 1), dark: UIColor(red: 0.239, green: 0.192, blue: 0.157, alpha: 1))

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    /// **Decorative glyphs only — never text.** `tertiaryLabel` measures about 1.7:1 on a
    /// light page, so anything carrying meaning (including a timestamp, which appears
    /// nowhere else on the row) belongs on `textSecondary`.
    static let textTertiary = Color(.tertiaryLabel)

    /// Accent for tinted text, icons, and strokes: a deep coffee brown in light mode, and
    /// a lighter warm caramel in dark mode so it still clears 4.5:1 against the espresso
    /// surface below — the same brown would go muddy-on-muddy there. Filled controls use
    /// `brandFill` instead.
    ///
    /// A literal color, not `Color.accentColor` — `AccentColor.colorset` still carries the
    /// same value for the few OS chrome spots that read it directly, but `Color.accentColor`
    /// proved to intermittently resolve to the system default blue instead of the asset in
    /// this project, so every in-app reference goes through this token instead.
    static let brand = Color.adaptive(light: UIColor(red: 0.290, green: 0.184, blue: 0.133, alpha: 1), dark: UIColor(red: 0.859, green: 0.643, blue: 0.420, alpha: 1))
    /// Filled surfaces that carry white text or glyphs. Adaptive for the same reason as
    /// `brand`: the light-mode coffee brown reads as almost-black against the espresso
    /// page in dark mode, so dark mode steps up to a lighter roast that still clears
    /// 4.5:1 for white text (5.1:1) while staying visually distinct from the surface under it.
    static let brandFill = Color.adaptive(light: UIColor(red: 0.290, green: 0.184, blue: 0.133, alpha: 1), dark: UIColor(red: 0.588, green: 0.388, blue: 0.247, alpha: 1))
    /// Low-tint brand wash for chip fills and selected states.
    ///
    /// **Flat, not transparent.** Every color in this palette is opaque: the value below
    /// is the brand color already composited onto the page, computed once here rather
    /// than left to the compositor at every call site. A translucent fill borrows
    /// whatever is behind it, which on a photo-heavy screen means the same token renders
    /// a different color in every row — the opposite of what a token is for.
    static let brandWash = Color.adaptive(light: UIColor(red: 0.911, green: 0.883, blue: 0.849, alpha: 1), dark: UIColor(red: 0.229, green: 0.172, blue: 0.127, alpha: 1))
    /// The brand at reduced emphasis for large decorative glyphs (empty states, avatar
    /// placeholders). Pre-composited onto the page for the same reason as `brandWash`.
    static let brandMuted = Color.adaptive(light: UIColor(red: 0.556, green: 0.485, blue: 0.437, alpha: 1), dark: UIColor(red: 0.580, green: 0.435, blue: 0.294, alpha: 1))
    /// The faintest brand step: the oversized rank numerals on the nearby strip, which
    /// are ornament rather than content.
    static let brandFaint = Color.adaptive(light: UIColor(red: 0.739, green: 0.689, blue: 0.650, alpha: 1), dark: UIColor(red: 0.372, green: 0.278, blue: 0.193, alpha: 1))
    /// 1pt outline on a brand-tinted control (the prominent secondary button).
    static let brandBorder = Color.adaptive(light: UIColor(red: 0.632, green: 0.569, blue: 0.527, alpha: 1), dark: UIColor(red: 0.513, green: 0.384, blue: 0.259, alpha: 1))

    // Status colors are tuned to clear 4.5:1 against the surface they appear on —
    // the warm page in light mode, espresso in dark. `rating` is the exception: it tints
    // non-text star glyphs, so it targets the 3:1 non-text threshold, and filled-versus-
    // outline shape carries the rating regardless of color.
    static let like = Color.adaptive(light: UIColor(red: 0.875, green: 0.176, blue: 0.271, alpha: 1), dark: UIColor(red: 1.0, green: 0.32, blue: 0.40, alpha: 1))
    static let rating = Color.adaptive(light: UIColor(red: 0.776, green: 0.533, blue: 0.035, alpha: 1), dark: UIColor(red: 1.0, green: 0.76, blue: 0.22, alpha: 1))
    static let success = Color.adaptive(light: UIColor(red: 0.106, green: 0.533, blue: 0.271, alpha: 1), dark: UIColor(red: 0.27, green: 0.80, blue: 0.46, alpha: 1))
    static let danger = Color.adaptive(light: UIColor(red: 0.80, green: 0.15, blue: 0.15, alpha: 1), dark: UIColor(red: 1.0, green: 0.42, blue: 0.40, alpha: 1))
    /// Backing for an inline error banner — `danger` composited onto the page.
    static let dangerWash = Color.adaptive(light: UIColor(red: 0.962, green: 0.880, blue: 0.851, alpha: 1), dark: UIColor(red: 0.198, green: 0.116, blue: 0.104, alpha: 1))

    /// The 0.5pt rule between rows and sections. Warm rather than the system's cool gray,
    /// and defined per theme so it never disappears in one of them — a divider that only
    /// exists in light mode is the most common way a flat, shadowless layout falls apart.
    static let hairline = Color.adaptive(light: UIColor(red: 0.871, green: 0.824, blue: 0.761, alpha: 1), dark: UIColor(red: 0.290, green: 0.231, blue: 0.196, alpha: 1))
    /// 1pt outline on something tappable — a text field, an outline button. Heavier than
    /// `hairline` on purpose so an interactive edge never reads as a divider.
    static let border = Color.adaptive(light: UIColor(red: 0.804, green: 0.741, blue: 0.659, alpha: 1), dark: UIColor(red: 0.373, green: 0.302, blue: 0.255, alpha: 1))

    /// Backing for anything that sits directly on a photo: page dots, an image counter,
    /// a remove button, the busy state over an avatar.
    ///
    /// Solid espresso rather than translucent black. A photo can be any color, so a
    /// translucent chip has no guaranteed contrast against the pixels beneath it; an
    /// opaque chip always clears 3:1 for the white glyph on top of it, and it is the one
    /// dark surface the palette already owns.
    static let overlayChrome = Color(.sRGB, red: 0.109, green: 0.082, blue: 0.071, opacity: 1)
    /// The muted state of a white element on `overlayChrome` (an inactive page dot),
    /// as a color rather than as opacity.
    static let overlayChromeMuted = Color(.sRGB, red: 0.541, green: 0.522, blue: 0.514, opacity: 1)
}

/// The type scale. Every role is SF Rounded — the brand's voice is warm and soft rather
/// than the system grotesque — and every role is declared `relativeTo:` a system text
/// style so Dynamic Type keeps scaling it.
///
/// Hierarchy in this system is carried by type, not by boxes. `label` is the editorial
/// signature: an uppercase, tracked caption that heads a section where a heavier design
/// would draw a card around it.
enum BumpFont {
    /// Screen hero — the one line that opens a screen with nothing above it.
    static let display = Font.system(.largeTitle, design: .rounded, weight: .bold)
    /// Screen and sheet titles.
    static let title = Font.system(.title2, design: .rounded, weight: .bold)
    /// Block titles, account names, primary row text.
    static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    /// A shop name, a prominent subtitle.
    static let subheadline = Font.system(.subheadline, design: .rounded, weight: .semibold)
    /// Running content: captions, comment bodies, descriptions.
    static let body = Font.system(.body, design: .rounded, weight: .regular)
    /// Supporting content set one step down from `body`.
    static let callout = Font.system(.subheadline, design: .rounded, weight: .regular)
    /// Timestamps, distances, counts-in-prose. Always on `textSecondary`.
    static let meta = Font.system(.footnote, design: .rounded, weight: .medium)
    /// The smallest role that still carries words: a field hint, a character counter, a
    /// photo-count badge. One step below `meta` and never used for running content —
    /// anything a user has to *read* rather than *check* belongs on `callout` or higher.
    static let caption = Font.system(.caption, design: .rounded, weight: .medium)
    /// Button and chip text.
    static let control = Font.system(.subheadline, design: .rounded, weight: .semibold)
    /// A one-time code being typed in. Monospaced *by design*, not just in its digits:
    /// a 6-digit code is read back character by character against the message it came
    /// from, and an even advance is what makes that possible. The only role in the app
    /// that is not SF Rounded, and the exception is the point.
    static let code = Font.system(.title, design: .monospaced, weight: .semibold)
    /// Counts next to an icon. Monospaced digits so a like count ticking 99 → 100 doesn't
    /// shove the row next to it sideways.
    static let numeric = Font.system(.subheadline, design: .rounded, weight: .semibold).monospacedDigit()
}

extension Text {
    /// The editorial section label: uppercase, tracked, small, secondary.
    ///
    /// **The uppercasing happens here, not in the string.** Call sites pass ordinary
    /// sentence-case text ("Nearby & highly rated") so the localisation catalogue holds a
    /// readable key a translator can work with — and so Vietnamese, where shouting a
    /// diacritic-heavy phrase in caps reads badly, can be restyled in one place rather
    /// than by rewriting every key.
    func bumpSectionLabel() -> some View {
        self
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(BumpColor.textSecondary)
            .textCase(.uppercase)
    }
}

/// Icon point sizes. Call sites wrap these in `@ScaledMetric` so glyphs grow with
/// Dynamic Type alongside the text they sit next to.
enum BumpIconSize {
    static let xs: CGFloat = 13
    static let small: CGFloat = 17
    static let medium: CGFloat = 22
    static let large: CGFloat = 28
    static let hero: CGFloat = 40
}

/// Motion tokens. Timing is chosen per *kind* of change, not copied from one duration:
/// a press is near-instant, a layout change settles, and a celebratory state change is
/// allowed to overshoot. Every one of them goes through `bumpAnimation`, which drops to
/// no animation under Reduce Motion.
enum BumpMotion {
    /// Press states and tint swaps — fast enough to feel like direct manipulation.
    static let quick = Animation.spring(response: 0.22, dampingFraction: 0.95)
    /// The default: content appearing, layout settling, sheets and pushes.
    static let standard = Animation.spring(response: 0.34, dampingFraction: 0.86)
    /// A deliberate overshoot for the small moments worth celebrating — a like landing,
    /// a save confirming. Used sparingly; everywhere is nowhere.
    static let bouncy = Animation.spring(response: 0.40, dampingFraction: 0.62)
    /// Pure fades, where a spring on opacity would just look indecisive.
    static let fade = Animation.easeOut(duration: 0.22)
    /// The skeleton's breathing. Slow and symmetric on purpose: a placeholder that
    /// pulses at interaction speed reads as a control waiting to be tapped, and one that
    /// eases asymmetrically reads as a heartbeat. This is the one loop in the app, so it
    /// is the one animation allowed to repeat forever.
    static let pulse = Animation.easeInOut(duration: 1.1).repeatForever(autoreverses: true)
}

extension View {
    /// `animation(_:value:)` that collapses to no animation when the user has asked the
    /// system to reduce motion. Content still reaches its final state; it just doesn't
    /// travel there.
    func bumpAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(ReduceMotionAnimation(animation: animation, value: value))
    }
}

private struct ReduceMotionAnimation<V: Equatable>: ViewModifier {
    let animation: Animation?
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}
