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

/// Semantic colors layered on top of system colors so every screen stays
/// consistent and adapts automatically to light/dark mode and increased contrast.
enum BumpColor {
    static let surface = Color(.systemBackground)
    static let surfaceSecondary = Color(.secondarySystemBackground)
    static let surfaceTertiary = Color(.tertiarySystemBackground)
    static let fill = Color(.tertiarySystemFill)

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
