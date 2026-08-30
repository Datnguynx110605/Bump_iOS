import UIKit

extension UIImage {
    /// Redraws the image so `imageOrientation == .up` and pixel buffer dimensions match
    /// what's visually displayed. Camera captures and library picks can carry EXIF
    /// rotation that `CGImage`-level code (crop math, thumbnailing) doesn't know about
    /// unless this runs first.
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
