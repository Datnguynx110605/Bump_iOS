import SwiftUI

/// The exact colors baked into the app icon PNG. Declared here rather than read from the
/// asset catalog so the icon renderer and the in-app mark are driven by one source —
/// `Tools/RenderAppIcon.swift` compiles this very file.
enum BumpBrandPalette {
    static let gradientStart = Color(.sRGB, red: 1.000, green: 0.545, blue: 0.400, opacity: 1)
    static let gradientEnd = Color(.sRGB, red: 0.902, green: 0.267, blue: 0.153, opacity: 1)

    static var gradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart, gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Bump's brand mark: a location pin with a coffee cup and saucer punched out of its
/// head. The pin says "a place"; the cup says "which kind of place" — a plain pin on its
/// own reads as a maps app and says nothing about coffee shops or restaurants.
///
/// Every hole is a subpath of one `Path`, so the whole mark renders as a single filled
/// shape with the even-odd rule and can be tinted, scaled, or animated as one unit.
/// **Fill with `FillStyle(eoFill: true)`** — the nested subpaths are meaningless without it.
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
        // Nudged off the head's exact centre: the handle throws the cup group's visual
        // mass to the right, and the group's own centre sits above `cy` because the
        // saucer hangs below the body.
        addCup(to: &path, cx: cx - 0.016 * u, cy: cy + 0.018 * u, u: u)
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

    // MARK: - Cup cutout

    /// Cup body, saucer, and handle, all as cutouts.
    ///
    /// The handle is a closed "C" whose four endpoints sit exactly **on** the cup's
    /// straight right edge, so the two holes meet without their areas overlapping.
    /// Punching it as a plain ring instead — outer circle plus inner circle — makes the
    /// overlap with the cup XOR back to solid under the even-odd rule and fuses the two
    /// into a blob.
    private func addCup(to path: inout Path, cx: CGFloat, cy: CGFloat, u: CGFloat) {
        let topY = cy - 0.120 * u
        let bottomY = cy + 0.038 * u
        let topHalf = 0.100 * u
        let bottomHalf = 0.070 * u
        let corner = 0.024 * u

        /// Half-width of the tapering cup body at a given y — the handle attaches to this
        /// edge, so both shapes read the same taper.
        func halfWidth(atY y: CGFloat) -> CGFloat {
            let t = (y - topY) / (bottomY - topY)
            return topHalf + t * (bottomHalf - topHalf)
        }

        path.move(to: CGPoint(x: cx - topHalf, y: topY))
        path.addLine(to: CGPoint(x: cx + topHalf, y: topY))
        path.addLine(to: CGPoint(x: cx + bottomHalf, y: bottomY - corner))
        path.addQuadCurve(
            to: CGPoint(x: cx + bottomHalf - corner, y: bottomY),
            control: CGPoint(x: cx + bottomHalf, y: bottomY)
        )
        path.addLine(to: CGPoint(x: cx - bottomHalf + corner, y: bottomY))
        path.addQuadCurve(
            to: CGPoint(x: cx - bottomHalf, y: bottomY - corner),
            control: CGPoint(x: cx - bottomHalf, y: bottomY)
        )
        path.closeSubpath()

        // Saucer: a capsule just below the cup, so it stays a saucer rather than a slab
        // at small sizes.
        let saucerHalf = 0.142 * u
        let saucerTop = cy + 0.052 * u
        let saucerHeight = 0.038 * u
        path.addRoundedRect(
            in: CGRect(x: cx - saucerHalf, y: saucerTop, width: saucerHalf * 2, height: saucerHeight),
            cornerSize: CGSize(width: saucerHeight / 2, height: saucerHeight / 2)
        )

        let outerTopY = cy - 0.085 * u
        let outerBotY = cy + 0.000 * u
        let innerTopY = cy - 0.064 * u
        let innerBotY = cy - 0.021 * u
        let outerBulge = cx + 0.205 * u
        let innerBulge = cx + 0.160 * u

        path.move(to: CGPoint(x: cx + halfWidth(atY: outerTopY), y: outerTopY))
        path.addCurve(
            to: CGPoint(x: cx + halfWidth(atY: outerBotY), y: outerBotY),
            control1: CGPoint(x: outerBulge, y: outerTopY),
            control2: CGPoint(x: outerBulge, y: outerBotY)
        )
        path.addLine(to: CGPoint(x: cx + halfWidth(atY: innerBotY), y: innerBotY))
        path.addCurve(
            to: CGPoint(x: cx + halfWidth(atY: innerTopY), y: innerTopY),
            control1: CGPoint(x: innerBulge, y: innerBotY),
            control2: CGPoint(x: innerBulge, y: innerTopY)
        )
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
