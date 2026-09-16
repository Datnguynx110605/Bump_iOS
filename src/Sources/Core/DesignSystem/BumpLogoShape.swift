import SwiftUI

/// The exact colors baked into the app icon PNG. Declared here rather than read from the
/// asset catalog so the icon renderer and the in-app mark are driven by one source —
/// `Tools/RenderAppIcon.swift` compiles this very file.
///
/// **One flat color, no gradient.** The app's design language is flat and opaque
/// everywhere else (see the header of `Theme.swift`), and the tile is the same coffee
/// brown as `BumpColor.brandFill` in light mode — so the icon on the home screen, the
/// splash, and every filled button in the app are literally the same color.
enum BumpBrandPalette {
    static let tile = Color(.sRGB, red: 0.290, green: 0.184, blue: 0.133, opacity: 1)
    static let mark = Color.white
}

/// Bump's brand mark: a plate and a coffee cup, side by side. Between them they name the
/// two things the app is for — a meal worth the trip and a coffee worth the corner table
/// — in one silhouette that still reads at home-screen size.
///
/// The whole mark is a single `Path` whose holes (the plate's well, the cup's handle) are
/// subpaths, so it renders as one filled shape and can be tinted, scaled, or animated as a
/// unit. **Fill with `FillStyle(eoFill: true)`** — the nested subpaths are meaningless
/// without it.
///
/// Two details that are easy to get wrong:
///
/// - The handle's hole is a D, not a circle. A full circle centred on the cup wall would
///   cut a bite out of the wall itself, because even-odd treats any enclosed subpath as a
///   hole wherever it lands. Flattening its left edge against the wall keeps the cup solid.
/// - The body and the handle are drawn as **one** outline rather than as two overlapping
///   shapes, for the same reason: under even-odd, an overlap is a hole.
struct BumpLogoShape: Shape {
    /// The mark is wide and short, so it is laid out in an *ink box* — a 1 × `inkAspect`
    /// rectangle that the drawing exactly fills — and that box is fitted to the width of
    /// whatever frame the shape is given, centred vertically. Sizing by frame height (the
    /// obvious thing) makes the mark overflow its tile, because the ink is barely half as
    /// tall as it is wide.
    static let inkAspect: CGFloat = 0.49

    // Plate, seen from above: an even ring, bottom-aligned with the cup.
    private let plateRadius: CGFloat = 0.245
    private let plateWellRatio: CGFloat = 0.55

    // Cup, seen from the side.
    private let cupLeft: CGFloat = 0.610
    private let cupRight: CGFloat = 0.900
    private let cupTop: CGFloat = 0.070
    private let cupBaseCorner: CGFloat = 0.075
    private let handleCenterY: CGFloat = 0.245
    private let handleOuterRadius: CGFloat = 0.100
    private let handleInnerRadius: CGFloat = 0.052

    func path(in rect: CGRect) -> Path {
        // Fit the ink box to the frame's width, centred vertically.
        let scale = rect.width
        let originY = rect.midY - Self.inkAspect * scale / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: originY + y * scale)
        }

        var path = Path()
        addPlate(to: &path, scale: scale, point: p)
        addCup(to: &path, scale: scale, point: p)
        return path
    }

    // MARK: - Plate

    /// Outer disc and inner well as two concentric circles. Even-odd turns the inner one
    /// into the hole, which is what makes a flat circle read as a plate rather than a dot.
    private func addPlate(to path: inout Path, scale: CGFloat, point p: (CGFloat, CGFloat) -> CGPoint) {
        let center = p(plateRadius, plateRadius)
        for radius in [plateRadius, plateRadius * plateWellRatio] {
            path.addEllipse(in: CGRect(
                x: center.x - radius * scale,
                y: center.y - radius * scale,
                width: radius * 2 * scale,
                height: radius * 2 * scale
            ))
        }
    }

    // MARK: - Cup

    /// Body and handle are drawn as one outline — down the right wall, out around the
    /// handle, back onto the wall — so the two never overlap as separate subpaths.
    private func addCup(to path: inout Path, scale: CGFloat, point p: (CGFloat, CGFloat) -> CGPoint) {
        let bottom = plateRadius * 2          // the cup stands on the plate's baseline
        let handleCenter = p(cupRight, handleCenterY)

        path.move(to: p(cupLeft, cupTop))
        path.addLine(to: p(cupRight, cupTop))
        path.addLine(to: p(cupRight, handleCenterY - handleOuterRadius))
        path.addArc(
            center: handleCenter,
            radius: handleOuterRadius * scale,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: p(cupRight, bottom - cupBaseCorner))
        path.addQuadCurve(to: p(cupRight - cupBaseCorner, bottom), control: p(cupRight, bottom))
        path.addLine(to: p(cupLeft + cupBaseCorner, bottom))
        path.addQuadCurve(to: p(cupLeft, bottom - cupBaseCorner), control: p(cupLeft, bottom))
        path.closeSubpath()

        // The handle's hole, flattened against the cup wall.
        path.move(to: p(cupRight, handleCenterY - handleInnerRadius))
        path.addArc(
            center: handleCenter,
            radius: handleInnerRadius * scale,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.closeSubpath()
    }
}

extension BumpLogoShape {
    /// The mark at a given drawn width. Height follows from `inkAspect`, so the returned
    /// view is exactly as large as the ink — nothing to centre by hand.
    static func mark(inkWidth: CGFloat, color: Color = BumpBrandPalette.mark) -> some View {
        BumpLogoShape()
            .fill(color, style: FillStyle(eoFill: true))
            .frame(width: inkWidth, height: inkWidth * inkAspect)
    }
}

/// The mark on its brand tile, matching the home-screen icon. Used wherever the app
/// introduces itself (onboarding) so the icon the user tapped and the first screen they
/// see are the same object.
struct BumpLogoMark: View {
    var size: CGFloat = 96

    /// The share of the tile the mark spans, matching `Tools/RenderAppIcon.swift`.
    static let markWidthFraction: CGFloat = 0.62

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
            .fill(BumpBrandPalette.tile)
            .frame(width: size, height: size)
            .overlay {
                BumpLogoShape.mark(inkWidth: size * Self.markWidthFraction)
            }
            .accessibilityHidden(true)
    }
}
