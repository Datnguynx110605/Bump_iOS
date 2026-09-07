// Renders Assets.xcassets/AppIcon.appiconset/icon-1024.png from the app's own
// `BumpLogoShape`, so the home-screen icon can never drift from the splash and
// onboarding marks. Not part of the app target — `Tools/` sits outside `Sources/`.
//
//   swiftc -O Sources/Core/DesignSystem/BumpLogoShape.swift Tools/RenderAppIcon.swift \
//       -o /tmp/rendericon && /tmp/rendericon <output.png>
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
enum RenderAppIcon {
    static let side: CGFloat = 1024

    @MainActor
    static func main() {
    let outputPath = CommandLine.arguments.count > 1
        ? CommandLine.arguments[1]
        : "Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    let icon = ZStack {
        BumpBrandPalette.gradient
        BumpLogoShape.mark(inkHeight: side * 0.60)
    }
    .frame(width: side, height: side)

    let renderer = ImageRenderer(content: icon)
    renderer.scale = 1
    guard let rendered = renderer.cgImage else {
        fatalError("ImageRenderer produced no image")
    }

    // App icons must ship without an alpha channel, so composite onto an opaque
    // context rather than writing the renderer's output straight out.
    guard let context = CGContext(
        data: nil,
        width: Int(side),
        height: Int(side),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        fatalError("Could not create opaque context")
    }
    context.draw(rendered, in: CGRect(x: 0, y: 0, width: side, height: side))

    guard let flattened = context.makeImage() else { fatalError("Could not flatten image") }
    let url = URL(fileURLWithPath: outputPath)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not open \(outputPath) for writing")
    }
    CGImageDestinationAddImage(destination, flattened, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not write PNG") }
    print("wrote \(outputPath)")
}
}
