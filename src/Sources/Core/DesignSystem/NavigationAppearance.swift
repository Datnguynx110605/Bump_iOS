import SwiftUI
import UIKit

/// App-wide chrome styling applied once at launch.
///
/// ## Why this file exists at all
///
/// Built against the iOS 26 SDK, UIKit gives navigation bars, toolbars, and tab bars the
/// system's **Liquid Glass** treatment by default: translucent, refractive chrome that
/// samples and blurs the content scrolling underneath it. Nothing in this app's own code
/// asked for it — it arrives from the SDK.
///
/// Bump's design language is editorial and flat: one opaque warm page, no elevation, no
/// translucency. Glass chrome is the single loudest contradiction of that, so it is
/// switched off here rather than fought screen by screen.
///
/// **Two changes are load-bearing together, and neither works alone.**
///
/// 1. `UIDesignRequiresCompatibility` in `Info.plist` opts the app out of the iOS 26
///    design. Without it, SwiftUI's `TabView` draws its own floating, translucent glass
///    tab bar that no `UITabBar.appearance()` proxy can reach — verified on device: the
///    appearance code below had *no* visible effect on the tab bar until that key was set.
/// 2. The appearance proxies here. With the compatibility key set, UIKit falls back to the
///    legacy appearance path, which is what makes these colours apply at all.
///
/// Delete either one and the glass — or the system-blue tint — comes back. They are not
/// redundant.
///
/// `configureWithOpaqueBackground()` is what kills the translucency. It discards the
/// system's blur material and paints a flat colour, and setting that colour to
/// `BumpColor.surface` makes the bars *disappear into the page* — which is the point. An
/// editorial layout has no visible frame around its content; the title simply sits at the
/// top of the paper.
///
/// A single set of appearance proxies reaches every screen's `navigationTitle` and the
/// one `TabView`, so this replaces what would otherwise be a modifier on each of ~20
/// screens.
enum BumpNavigationAppearance {
    static func configure() {
        configureNavigationBar()
        configureTabBar()
    }

    private static func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(BumpColor.surface)
        // No shadow line under the bar. The page continues straight through it; where a
        // boundary is genuinely needed a screen draws its own `BumpDivider`, which is
        // warm and 0.5pt rather than the system's cool 1px.
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .font: UIFont.bumpRounded(textStyle: .headline, weight: .semibold),
            .foregroundColor: UIColor.label,
        ]
        appearance.largeTitleTextAttributes = [
            .font: UIFont.bumpRounded(textStyle: .largeTitle, weight: .bold),
            .foregroundColor: UIColor.label,
        ]

        // Back button and bar-button items in the brand brown rather than system blue.
        let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
        buttonAppearance.normal.titleTextAttributes = [
            .font: UIFont.bumpRounded(textStyle: .body, weight: .medium),
            .foregroundColor: UIColor(BumpColor.brand),
        ]
        appearance.buttonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance
        appearance.doneButtonAppearance = buttonAppearance

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.compactScrollEdgeAppearance = appearance
        bar.tintColor = UIColor(BumpColor.brand)
    }

    private static func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(BumpColor.surface)
        // The tab bar is the one place the flat page *does* need a boundary: content
        // scrolls underneath it, so without a rule the last row of a list merges into the
        // tab labels. A hairline is enough; a shadow would reintroduce elevation.
        appearance.shadowColor = UIColor(BumpColor.hairline)

        for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = UIColor(BumpColor.textSecondary)
            item.normal.titleTextAttributes = [
                .font: UIFont.bumpRounded(textStyle: .caption2, weight: .medium),
                .foregroundColor: UIColor(BumpColor.textSecondary),
            ]
            item.selected.iconColor = UIColor(BumpColor.brand)
            item.selected.titleTextAttributes = [
                .font: UIFont.bumpRounded(textStyle: .caption2, weight: .semibold),
                .foregroundColor: UIColor(BumpColor.brand),
            ]
        }

        let bar = UITabBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.tintColor = UIColor(BumpColor.brand)
        bar.unselectedItemTintColor = UIColor(BumpColor.textSecondary)
    }
}

private extension UIFont {
    /// SF Rounded at a given text style's size, scaled with `UIFontMetrics` so Dynamic
    /// Type keeps working exactly as it does for the system default. This is the UIKit
    /// half of `BumpFont` — the bars are UIKit, so the same rounded voice has to be
    /// rebuilt here rather than imported.
    static func bumpRounded(textStyle: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: textStyle)
        let system = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
        let rounded = system.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: base.pointSize) } ?? system
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: rounded)
    }
}
