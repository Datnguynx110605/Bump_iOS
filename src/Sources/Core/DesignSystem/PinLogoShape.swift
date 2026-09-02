import SwiftUI

/// The same bold pin silhouette as the app icon (a solid, rounded head tapering to a
/// point, with a punched-out circle at its center), redrawn as a vector `Shape` so it
/// can be tinted with `Color.accentColor` and animated in-app instead of shipped as a
/// fixed bitmap. Fill with the even-odd rule (`.fill(style: FillStyle(eoFill: true))`)
/// so the center hole reads as a cutout rather than a solid dot.
struct PinLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let cx = rect.midX
        let cy = rect.minY + size * 0.375
        let radius = size * 0.28
        let tipY = rect.minY + size * 0.89
        let anchorAngle = 35.0
        let pull = size * 0.24

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

        var path = Path()
        path.move(to: rightAnchor)
        path.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: radius,
            startAngle: .degrees(thetaRight),
            endAngle: .degrees(thetaLeft),
            clockwise: true
        )
        path.addCurve(to: tip, control1: control1, control2: CGPoint(x: tip.x - size * 0.09, y: tip.y - size * 0.10))
        path.addCurve(to: rightAnchor, control1: CGPoint(x: tip.x + size * 0.09, y: tip.y - size * 0.10), control2: control2)
        path.closeSubpath()

        let holeRadius = radius * 0.40
        path.addEllipse(in: CGRect(x: cx - holeRadius, y: cy - holeRadius, width: holeRadius * 2, height: holeRadius * 2))

        return path
    }
}
