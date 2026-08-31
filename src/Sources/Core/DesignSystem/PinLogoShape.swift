import SwiftUI

/// The same pin silhouette as the app icon (a circle "head" with an open teardrop
/// tail beneath it), redrawn as a vector `Shape` so it can be tinted with
/// `Color.accentColor` and animated in-app instead of shipped as a fixed bitmap.
struct PinLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let cx = rect.midX
        let cy = rect.minY + size * 0.40
        let radius = size * 0.165
        let tipY = rect.minY + size * 0.775

        func onCircle(_ degrees: Double) -> CGPoint {
            let rad = degrees * .pi / 180
            return CGPoint(x: cx + radius * cos(rad), y: cy + radius * sin(rad))
        }

        let tip = CGPoint(x: cx, y: tipY)
        let leftAnchor = onCircle(140)
        let rightAnchor = onCircle(40)

        var path = Path()
        path.move(to: leftAnchor)
        path.addCurve(
            to: tip,
            control1: CGPoint(x: leftAnchor.x - size * 0.02, y: leftAnchor.y + size * 0.16),
            control2: CGPoint(x: tip.x - size * 0.07, y: tip.y - size * 0.10)
        )
        path.addCurve(
            to: rightAnchor,
            control1: CGPoint(x: tip.x + size * 0.07, y: tip.y - size * 0.10),
            control2: CGPoint(x: rightAnchor.x + size * 0.02, y: rightAnchor.y + size * 0.16)
        )

        path.addEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))

        let holeRadius = radius * 0.42
        path.addEllipse(in: CGRect(x: cx - holeRadius, y: cy - holeRadius, width: holeRadius * 2, height: holeRadius * 2))

        return path
    }
}
