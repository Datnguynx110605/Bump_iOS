import SwiftUI
import UIKit

enum BumpSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
}

enum BumpRadius {
    static let card: CGFloat = 20
    static let control: CGFloat = 14
    static let pill: CGFloat = 100
}

extension Color {
    /// A dynamic color that swaps by appearance, so a single token can commit to a
    /// specific light palette while overriding what dark mode uses (e.g. true black
    /// instead of the system's default elevated dark grays).
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/// Semantic colors layered on top of system colors so every screen stays
/// consistent and adapts automatically to light/dark mode and increased contrast.
/// Dark mode intentionally commits to true black rather than the system's default
/// elevated dark grays, for a cleaner OLED-style look.
enum BumpColor {
    static let surface = Color.adaptive(light: .systemBackground, dark: .black)
    static let surfaceSecondary = Color.adaptive(light: .secondarySystemBackground, dark: UIColor(white: 0.07, alpha: 1))
    static let surfaceTertiary = Color.adaptive(light: .tertiarySystemBackground, dark: UIColor(white: 0.12, alpha: 1))
    static let fill = Color.adaptive(light: .tertiarySystemFill, dark: UIColor(white: 0.16, alpha: 1))

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    static let brand = Color.accentColor
    static let like = Color.red
    static let success = Color.green
    static let danger = Color.red

    static let separator = Color(.separator)
    static let overlayScrim = Color.black.opacity(0.45)
}

/// Icon point sizes that scale with Dynamic Type via `@ScaledMetric` at call sites,
/// tuned up from the app's original hand-picked sizes for legibility.
enum BumpIconSize {
    static let small: CGFloat = 18
    static let medium: CGFloat = 24
    static let large: CGFloat = 34
    static let hero: CGFloat = 44
}

enum BumpMotion {
    static let quick = Animation.easeOut(duration: 0.15)
    static let standard = Animation.easeInOut(duration: 0.25)
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
}
