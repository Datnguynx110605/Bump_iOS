import SwiftUI
import UIKit

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

enum BumpRadius {
    static let small: CGFloat = 10
    static let control: CGFloat = 14
    static let card: CGFloat = 20
}

/// Apple's minimum comfortable tap area. Icon-only controls are visually smaller than
/// this, so they expand their hit region to it rather than growing the glyph.
enum BumpHitTarget {
    static let min: CGFloat = 44
}

extension Color {
    /// A dynamic color that swaps by appearance, so a single token can commit to a
    /// specific light palette while overriding what dark mode uses (e.g. true black
    /// instead of the system's default elevated dark grays).
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/// Semantic colors layered on top of system colors so every screen stays consistent and
/// adapts automatically to light/dark mode.
///
/// Light mode is a warm, off-white paper tone with pure-white cards lifted on top of it —
/// calmer than flat system gray, and warm rather than cool for a food/coffee-spot app.
/// Dark mode mirrors that warmth with a deep espresso instead of the system's elevated
/// grays: never a true, cold black, but still dark enough for comfortable night use.
enum BumpColor {
    /// Page background, behind everything.
    static let surface = Color.adaptive(light: UIColor(red: 0.980, green: 0.961, blue: 0.929, alpha: 1), dark: UIColor(red: 0.109, green: 0.082, blue: 0.071, alpha: 1))
    /// Cards and raised content sitting on `surface`.
    static let surfaceSecondary = Color.adaptive(light: .white, dark: UIColor(red: 0.165, green: 0.125, blue: 0.098, alpha: 1))
    /// One level above a card: composer bars, selected rows, inline wells.
    static let surfaceTertiary = Color.adaptive(light: UIColor(red: 0.945, green: 0.914, blue: 0.867, alpha: 1), dark: UIColor(red: 0.200, green: 0.157, blue: 0.129, alpha: 1))
    /// Neutral placeholder block behind images that haven't decoded yet.
    static let fill = Color.adaptive(light: UIColor(red: 0.914, green: 0.875, blue: 0.820, alpha: 1), dark: UIColor(red: 0.239, green: 0.192, blue: 0.157, alpha: 1))

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    /// **Decorative glyphs only — never text.** `tertiaryLabel` measures about 1.7:1 on a
    /// light card, so anything carrying meaning (including a timestamp, which appears
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
    /// card in dark mode, so dark mode steps up to a lighter roast that still clears
    /// 4.5:1 for white text (5.1:1) while staying visually distinct from the card under it.
    static let brandFill = Color.adaptive(light: UIColor(red: 0.290, green: 0.184, blue: 0.133, alpha: 1), dark: UIColor(red: 0.588, green: 0.388, blue: 0.247, alpha: 1))

    // Status colors are tuned to clear 4.5:1 against the surface they appear on —
    // white cards in light mode, true black in dark. `rating` is the exception: it tints
    // non-text star glyphs, so it targets the 3:1 non-text threshold, and filled-versus-
    // outline shape carries the rating regardless of color.
    static let like = Color.adaptive(light: UIColor(red: 0.875, green: 0.176, blue: 0.271, alpha: 1), dark: UIColor(red: 1.0, green: 0.32, blue: 0.40, alpha: 1))
    static let rating = Color.adaptive(light: UIColor(red: 0.776, green: 0.533, blue: 0.035, alpha: 1), dark: UIColor(red: 1.0, green: 0.76, blue: 0.22, alpha: 1))
    static let success = Color.adaptive(light: UIColor(red: 0.106, green: 0.533, blue: 0.271, alpha: 1), dark: UIColor(red: 0.27, green: 0.80, blue: 0.46, alpha: 1))
    static let danger = Color.adaptive(light: UIColor(red: 0.80, green: 0.15, blue: 0.15, alpha: 1), dark: UIColor(red: 1.0, green: 0.42, blue: 0.40, alpha: 1))

    static let separator = Color(.separator)
    /// Hairline around cards. Carries the light-mode card/page separation, so it must
    /// stay visible in both themes rather than fading out in one.
    static let border = Color.adaptive(light: UIColor(red: 0.871, green: 0.824, blue: 0.761, alpha: 1), dark: UIColor(red: 0.333, green: 0.267, blue: 0.227, alpha: 1))
    static let overlayScrim = Color.black.opacity(0.45)
    /// Backing for small controls and badges that sit directly on a photo (page dots,
    /// a remove button, an image counter). Heavier than `overlayScrim` on purpose: a
    /// modal scrim covers the whole screen, while these are small shapes that have to
    /// clear 3:1 against whatever pixel happens to be under them.
    static let overlayChrome = Color.black.opacity(0.55)
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

enum BumpMotion {
    static let quick = Animation.easeOut(duration: 0.15)
    static let standard = Animation.easeInOut(duration: 0.25)
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
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
