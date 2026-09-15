import UIKit

/// The app's three haptic moments, named by *meaning* rather than by generator type so
/// call sites can't drift into using a heavy impact for a tab change.
///
/// Deliberately small. A haptic on every tap stops being feedback and becomes noise, so
/// these fire only where something genuinely changed state.
@MainActor
enum HapticFeedback {
    /// A reaction landed (like, save, follow) — the app's small celebratory moment.
    static func reacted() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A toggle switched on. Same weight as `reacted`; separate name so the *off*
    /// direction can stay silent without call sites having to remember why.
    static func toggledOn() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A discrete choice was made from a set — a rating star, a filter chip. Crisper and
    /// lighter than an impact, which is what the selection generator exists for.
    static func selected() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Something the user submitted succeeded.
    static func succeeded() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
