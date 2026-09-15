import SwiftUI

/// The exact colors baked into the app icon PNG. Declared here rather than read from the
/// asset catalog so the icon renderer and the in-app mark are driven by one source —
/// `Tools/RenderAppIcon.swift` compiles this very file.
enum BumpBrandPalette {
    static let gradientStart = Color(.sRGB, red: 0.788, green: 0.482, blue: 0.290, opacity: 1)
    static let gradientEnd = Color(.sRGB, red: 0.231, green: 0.141, blue: 0.082, opacity: 1)

    static var gradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart, gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Bump's brand mark: a location pin with a five-point star punched out of its head. The
/// pin says "a place"; the star says "worth rating" — the app's one repeated motif across
/// every post, shop, and profile (`RatingStarsView`), and a claim that holds for any kind
/// of spot rather than one narrower than the app itself (a coffee cup, say).
///
/// The star is a subpath of the same `Path` as the pin, so the whole mark renders as one
/// filled shape with the even-odd rule and can be tinted, scaled, or animated as one unit.
/// **Fill with `FillStyle(eoFill: true)`** — the nested subpath is meaningless without it.
struct BumpLogoShape: Shape {
    /// The drawn mark spans y ∈ [0.080, 0.895] of its frame and only 0.57 of its width,
    /// so sizing by the frame makes it look far smaller than it is. Tiles size against
    /// `inkHeightFraction` and nudge by `inkCenterOffset` to centre the ink optically.
    static let inkHeightFraction: CGFloat = 0.815
    static let inkCenterOffset: CGFloat = 0.0125

    func path(in rect: CGRect) -> Path {
        let u = min(rect.width, rect.height)
        let cx = rect.midX
        let cy = rect.minY + 0.365 * u

        var path = Path()
        addPin(to: &path, cx: cx, cy: cy, u: u, minY: rect.minY)
        addStar(to: &path, cx: cx, cy: cy + 0.010 * u, u: u)
        return path
    }

    // MARK: - Pin silhouette

    /// A circular head that tapers into a point: two symmetric curves leave the circle at
    /// `anchorAngle` and meet at the tip, with control points placed along the circle's
    /// tangent so the join is smooth rather than kinked.
    private func addPin(to path: inout Path, cx: CGFloat, cy: CGFloat, u: CGFloat, minY: CGFloat) {
        let radius = 0.285 * u
        let tipY = minY + 0.895 * u
        let anchorAngle = 34.0
        let pull = 0.245 * u

        func onCircle(_ degrees: Double) -> CGPoint {
            let rad = degrees * .pi / 180
            return CGPoint(x: cx + radius * cos(rad), y: cy + radius * sin(rad))
        }
        func tangent(_ degrees: Double) -> CGPoint {
            let rad = degrees * .pi / 180
            return CGPoint(x: sin(rad), y: -cos(rad))
        }

        let thetaRight = anchorAngle
        let thetaLeft = 180 - anchorAngle
        let leftAnchor = onCircle(thetaLeft)
        let rightAnchor = onCircle(thetaRight)
        let tip = CGPoint(x: cx, y: tipY)

        let leftTangent = tangent(thetaLeft)
        let control1 = CGPoint(x: leftAnchor.x + pull * leftTangent.x, y: leftAnchor.y + pull * leftTangent.y)
        let rightTangent = tangent(thetaRight)
        let control2 = CGPoint(x: rightAnchor.x - pull * rightTangent.x, y: rightAnchor.y - pull * rightTangent.y)

        path.move(to: rightAnchor)
        path.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: radius,
            startAngle: .degrees(thetaRight),
            endAngle: .degrees(thetaLeft),
            clockwise: true
        )
        path.addCurve(to: tip, control1: control1, control2: CGPoint(x: tip.x - 0.085 * u, y: tip.y - 0.095 * u))
        path.addCurve(to: rightAnchor, control1: CGPoint(x: tip.x + 0.085 * u, y: tip.y - 0.095 * u), control2: control2)
        path.closeSubpath()
    }

    // MARK: - Star cutout

    /// A five-point star, centred in the pin's head, as a single cutout. Straight edges
    /// rather than rounded points — at icon sizes a rounded star reads as a blob, while a
    /// crisp star silhouette matches the `star.fill` glyph used for ratings everywhere
    /// else in the app.
    private func addStar(to path: inout Path, cx: CGFloat, cy: CGFloat, u: CGFloat) {
        let outerRadius = 0.130 * u
        let innerRadius = outerRadius * 0.46
        let points = 5
        let step = Double.pi / Double(points)
        // Point-up: the first vertex sits straight above centre.
        let start = -Double.pi / 2

        func vertex(_ index: Int) -> CGPoint {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = start + Double(index) * step
            return CGPoint(x: cx + radius * cos(angle), y: cy + radius * sin(angle))
        }

        path.move(to: vertex(0))
        for index in 1..<(points * 2) {
            path.addLine(to: vertex(index))
        }
        path.closeSubpath()
    }
}

extension BumpLogoShape {
    /// The white mark, scaled so its *drawn* height is `inkHeight` and optically centred.
    static func mark(inkHeight: CGFloat, color: Color = .white) -> some View {
        let frame = inkHeight / inkHeightFraction
        return BumpLogoShape()
            .fill(color, style: FillStyle(eoFill: true))
            .frame(width: frame, height: frame)
            .offset(y: frame * inkCenterOffset)
    }
}

/// The mark on its brand tile, matching the home-screen icon. Used wherever the app
/// introduces itself (onboarding) so the icon the user tapped and the first screen they
/// see are the same object.
struct BumpLogoMark: View {
    var size: CGFloat = 96

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
            .fill(BumpBrandPalette.gradient)
            .frame(width: size, height: size)
            .overlay {
                BumpLogoShape.mark(inkHeight: size * 0.60)
            }
            .accessibilityHidden(true)
    }
}
