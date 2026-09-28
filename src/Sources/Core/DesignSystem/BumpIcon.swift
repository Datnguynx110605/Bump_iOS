import SwiftUI
import UIKit

// MARK: - The Bump icon family
//
// Bump draws its own icons rather than using SF Symbols. The reason is the same one
// behind every other token in `Theme.swift`: a glyph the app does not own is a glyph the
// app cannot keep consistent. SF Symbols ship several optical weights, two fill styles
// and their own idea of stroke terminals, and mixing them is how the app ended up with
// `bookmark` beside `bookmark.fill`, `ellipsis` beside `ellipsis.circle` and an outline
// `cup.and.saucer` beside a solid `person.fill` — four different answers to the same
// question on one screen.
//
// Every glyph here is drawn on the same 24×24 grid with the same construction rules:
//
// 1. **One stroke weight.** `strokeFraction` of the rendered size, round cap and round
//    join, so the family reads as one hand at every scale. Warm and soft, matching the
//    SF Rounded type it sits beside.
// 2. **One silhouette per concept.** Fill is a *state*, not a different icon.
//    `BumpIcon(.heart)` and `BumpIcon(.heart, .filled)` are the same path — the second
//    one filled — so a like turning on never changes shape, only weight.
// 3. **Modifiers compose.** `.slashed` and `.circled` are applied to a base glyph rather
//    than hand-drawn per icon, which is what guarantees every "disabled" and every
//    "badged" variant in the app is constructed identically.
//
// The geometry lives in `BumpIconGeometry.swift` so `Tools/RenderIconSheet` can compile
// the same paths on macOS and render a contact sheet — the icons are proofed by looking
// at them, not by trusting the numbers.

/// A glyph from the Bump icon family.
///
/// Sized in points like a font, and scaled by the caller with `@ScaledMetric` exactly the
/// way the old `Image(systemName:)` call sites were, so Dynamic Type still grows the
/// glyph alongside the text next to it.
///
/// Decorative by default: a `BumpIcon` is hidden from the accessibility tree unless it is
/// given a `label`. A glyph beside its own visible text is noise to VoiceOver, and an
/// icon-only control needs a name that describes the *action*, not the picture — neither
/// is served by announcing "heart".
struct BumpIcon: View {
    let glyph: BumpGlyph
    var variant: BumpGlyphVariant = .outline
    var size: CGFloat = BumpIconSize.medium
    /// Accessible name. `nil` (the default) hides the glyph from VoiceOver.
    var label: String? = nil

    init(
        _ glyph: BumpGlyph,
        _ variant: BumpGlyphVariant = .outline,
        size: CGFloat = BumpIconSize.medium,
        label: String? = nil
    ) {
        self.glyph = glyph
        self.variant = variant
        self.size = size
        self.label = label
    }

    var body: some View {
        BumpIconCanvas(glyph: glyph, variant: variant)
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .modifier(BumpIconAccessibility(label: label))
    }
}

/// Applies the accessible name, or removes the glyph from the tree when it has none.
private struct BumpIconAccessibility: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label)
        } else {
            content.accessibilityHidden(true)
        }
    }
}

/// The drawing itself, split out so `BumpIcon` stays a plain sized frame and the canvas
/// can be reused at a fixed size by the render tool.
///
/// `Canvas` rather than a stack of `Shape`s: a glyph is up to four sub-paths with two
/// different treatments (stroked, filled, knocked out), and a single canvas draws them in
/// one pass with one resolved foreground colour instead of composing four views.
struct BumpIconCanvas: View {
    let glyph: BumpGlyph
    var variant: BumpGlyphVariant = .outline

    var body: some View {
        Canvas { context, size in
            BumpIconGeometry.draw(
                glyph: glyph,
                variant: variant,
                in: CGSize(width: size.width, height: size.height),
                context: &context
            )
        }
        // The canvas paints with `.foreground`, so a `BumpIcon` inherits the tint of
        // whatever it is placed in exactly like `Image(systemName:)` did — call sites keep
        // using `.foregroundStyle`, and nothing has to pass a colour down.
    }
}

// MARK: - Pairing a glyph with text

/// The icon + text pairing that replaces `Label(_, systemImage:)`.
///
/// SwiftUI's `Label` sizes its icon from the surrounding font, which is what let icon
/// sizes drift across screens. This takes the size explicitly from `BumpIconSize` and
/// aligns the glyph to the text's *first baseline block* rather than its centre, so a
/// label that wraps to two lines keeps its icon beside the first line instead of floating
/// to the middle of the paragraph.
struct BumpLabel<Content: View>: View {
    let glyph: BumpGlyph
    var variant: BumpGlyphVariant = .outline
    var size: CGFloat = BumpIconSize.small
    @ViewBuilder var content: () -> Content

    @ScaledMetric private var scale: CGFloat = 1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BumpSpacing.s) {
            BumpIcon(glyph, variant, size: size * scale)
                // The glyph's box is square and the text's is not, so centring the two
                // boxes sits the icon visibly high. Nudging it down by an eighth of its
                // size lands it on the text's optical centre.
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - size * scale * 0.18 }
            content()
        }
    }
}

// MARK: - UIKit bridge

extension BumpGlyph {
    /// The glyph as a template `UIImage`.
    ///
    /// Two surfaces in the app are drawn by UIKit rather than SwiftUI — the tab bar and
    /// every context menu, both of which bridge to `UITabBarItem` / `UIMenu` and take a
    /// `UIImage`. A SwiftUI `Canvas` handed to either one renders as nothing at all, so
    /// those call sites go through here instead of through `BumpIcon`.
    ///
    /// Rendered from the same `BumpIconCanvas` the rest of the app draws, so the tab bar
    /// can never drift from the glyph beside it on the page. Template mode discards the
    /// colour, which is why it is drawn in flat black.
    @MainActor
    func templateImage(size: CGFloat, variant: BumpGlyphVariant = .outline) -> UIImage? {
        let key = Key(glyph: self, variant: variant, size: size)
        if let cached = Self.imageCache[key] { return cached }

        let renderer = ImageRenderer(
            content: BumpIconCanvas(glyph: self, variant: variant)
                .frame(width: size, height: size)
                .foregroundStyle(.black)
        )
        renderer.scale = UITraitCollection.current.displayScale
        guard let image = renderer.uiImage?.withRenderingMode(.alwaysTemplate) else { return nil }

        Self.imageCache[key] = image
        return image
    }

    private struct Key: Hashable {
        let glyph: BumpGlyph
        let variant: BumpGlyphVariant
        let size: CGFloat
    }

    /// Rasterising a glyph costs a render pass, and the tab bar asks for the same five
    /// on every layout. The set is tiny and fixed, so it is held for the process rather
    /// than evicted.
    @MainActor
    private static var imageCache: [Key: UIImage] = [:]
}

extension BumpGlyphVariant: Hashable {}

/// A glyph for a bar button — anything inside `.toolbar { }`.
///
/// Same reasoning as the tab bar: SwiftUI hands toolbar content to `UIBarButtonItem`,
/// and while a custom SwiftUI view is *usually* hosted intact there, a `Canvas` that
/// fails to render leaves a bar button with nothing in it and no error. There is a path
/// that is guaranteed to work and it costs nothing, so the bars take it.
///
/// Sized at `BumpIconSize.medium` — bar buttons don't scale with Dynamic Type, so
/// rasterising at a fixed size loses nothing.
struct BumpBarIcon: View {
    let glyph: BumpGlyph
    var variant: BumpGlyphVariant = .outline

    init(_ glyph: BumpGlyph, _ variant: BumpGlyphVariant = .outline) {
        self.glyph = glyph
        self.variant = variant
    }

    var body: some View {
        if let image = glyph.templateImage(size: BumpIconSize.medium, variant: variant) {
            Image(uiImage: image)
        }
    }
}

/// A menu row: the label shape `Menu` and `.contextMenu` bridge into `UIMenu`.
///
/// `Button(_, systemImage:)` is unavailable once the app stops using SF Symbols, and a
/// `BumpIcon` inside a menu label draws nothing, so menu rows build a real `Image` from
/// the glyph instead.
struct BumpMenuButton: View {
    let title: LocalizedStringKey
    let glyph: BumpGlyph
    var variant: BumpGlyphVariant = .outline
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label {
                Text(title)
            } icon: {
                if let image = glyph.templateImage(size: BumpIconSize.medium, variant: variant) {
                    Image(uiImage: image)
                }
            }
        }
    }
}

extension BumpLabel where Content == Text {
    init(_ title: LocalizedStringKey, glyph: BumpGlyph, variant: BumpGlyphVariant = .outline, size: CGFloat = BumpIconSize.small) {
        self.init(glyph: glyph, variant: variant, size: size) { Text(title) }
    }

    init(verbatim title: String, glyph: BumpGlyph, variant: BumpGlyphVariant = .outline, size: CGFloat = BumpIconSize.small) {
        self.init(glyph: glyph, variant: variant, size: size) { Text(title) }
    }
}
