import UIKit

/// App-wide chrome styling applied once at launch. A single `UINavigationBarAppearance`
/// reaches every screen's `navigationTitle`, so the brand's rounded, friendly voice
/// (warm and soft rather than the default system grotesque) shows up everywhere without
/// touching each of the ~20 screens that set one.
enum BumpNavigationAppearance {
    static func configure() {
        // `configureWithDefaultBackground()` reproduces the system's own opaque
        // background/shadow so this reads as "same chrome, new font" — only the title
        // attributes below are actually different from what UIKit already draws.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.titleTextAttributes = [.font: UIFont.bumpRounded(textStyle: .headline)]
        appearance.largeTitleTextAttributes = [.font: UIFont.bumpRounded(textStyle: .largeTitle)]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}

private extension UIFont {
    /// SF Rounded at a given text style's weight and size, scaled with `UIFontMetrics` so
    /// Dynamic Type keeps working exactly as it does for the system default.
    static func bumpRounded(textStyle: UIFont.TextStyle) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: textStyle)
        let weight: UIFont.Weight = textStyle == .largeTitle ? .bold : .semibold
        let system = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
        let rounded = system.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: base.pointSize) } ?? system
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: rounded)
    }
}
