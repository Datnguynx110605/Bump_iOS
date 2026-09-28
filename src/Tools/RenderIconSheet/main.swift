// Renders the whole Bump icon family to a PNG contact sheet so the hand-drawn vectors
// can be proofed by eye. Hand-authored path data is the one part of the design system a
// typecheck cannot validate — a glyph with a transposed coordinate compiles perfectly and
// looks like nothing.
//
// Draws every glyph at three sizes (13 / 22 / 40pt, the family's real range) plus each
// variant, because the failure modes are size-dependent: strokes merge at 13pt and
// knockouts look thin at 40pt.
//
//   cd Bump_iOS/src
//   swiftc -O Sources/Core/DesignSystem/BumpIconGeometry.swift Tools/RenderIconSheet/main.swift \
//       -o /tmp/rendericonsheet && /tmp/rendericonsheet <output.png>

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// The sheet is drawn on the app's real surfaces, in the app's real ink, so the proof
// shows the glyphs at the contrast they actually ship at.
//
// Both themes, because a stroke weight that reads right as dark-on-paper reads thinner
// as light-on-espresso at the same number — light strokes bloom against a dark ground.
// Pass `dark` as the second argument to render the dark pass.
private let isDark = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "dark"
private let paper = isDark
    ? Color(red: 0.109, green: 0.082, blue: 0.071)
    : Color(red: 0.980, green: 0.961, blue: 0.929)
private let ink = isDark
    ? Color(red: 0.859, green: 0.643, blue: 0.420)
    : Color(red: 0.290, green: 0.184, blue: 0.133)

// The two places a glyph sits on `overlayChrome` rather than on the page: the
// multi-photo badge and the carousel counter. White on espresso, at the smallest size
// the app uses, is where a hairline stroke is most likely to disappear.
private let overlayChrome = Color(red: 0.109, green: 0.082, blue: 0.071)

private struct Cell: View {
    let glyph: BumpGlyph
    let variant: BumpGlyphVariant
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            var ctx = context
            BumpIconGeometry.draw(glyph: glyph, variant: variant, in: canvasSize, context: &ctx)
        }
        .frame(width: size, height: size)
        .foregroundStyle(ink)
    }
}

private struct Row: View {
    let glyph: BumpGlyph

    var body: some View {
        HStack(spacing: 18) {
            Text(glyph.rawValue)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ink.opacity(0.75))
                .frame(width: 110, alignment: .leading)

            // Three sizes of the plain outline: the stroke weight is a fraction of the
            // size, so this row is where a weight that reads heavy at 13pt shows up.
            Cell(glyph: glyph, variant: .outline, size: 13)
            Cell(glyph: glyph, variant: .outline, size: 22)
            Cell(glyph: glyph, variant: .outline, size: 40)

            Divider().frame(height: 30)

            // Every variant at one size, to check that fill, slash and circle all still
            // resolve to the same object.
            Cell(glyph: glyph, variant: .filled, size: 28)
            Cell(glyph: glyph, variant: .slashed, size: 28)
            Cell(glyph: glyph, variant: .circled, size: 28)
            Cell(glyph: glyph, variant: .circledFilled, size: 28)
        }
        .frame(height: 48)
    }
}

private struct Sheet: View {
    // Two columns, because 38 glyphs in one column is a 1900pt-tall image nothing can
    // read at a glance.
    var body: some View {
        let glyphs = BumpGlyph.allCases
        let half = (glyphs.count + 1) / 2

        HStack(alignment: .top, spacing: 40) {
            column(Array(glyphs[..<half]))
            VStack(alignment: .leading, spacing: 0) {
                column(Array(glyphs[half...]))
                OverlayProof()
            }
        }
        .padding(28)
        .background(paper)
    }

    private func column(_ glyphs: [BumpGlyph]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 18) {
                Text("glyph")
                    .frame(width: 110, alignment: .leading)
                Text("13").frame(width: 13)
                Text("22").frame(width: 22)
                Text("40").frame(width: 40)
                Divider().frame(height: 12)
                Text("fill").frame(width: 28)
                Text("slash").frame(width: 28)
                Text("ring").frame(width: 28)
                Text("solid").frame(width: 28)
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(ink.opacity(0.55))
            .padding(.bottom, 6)

            ForEach(glyphs, id: \.self) { Row(glyph: $0) }
        }
    }
}

/// White-on-chrome proof: the badge treatment, at the exact size it ships at.
private struct OverlayProof: View {
    var body: some View {
        HStack(spacing: 14) {
            Text("on overlayChrome @13")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(ink.opacity(0.55))
            ForEach([BumpGlyph.copy, .photos, .camera], id: \.self) { glyph in
                Canvas { context, size in
                    var ctx = context
                    BumpIconGeometry.draw(glyph: glyph, variant: .outline, in: size, context: &ctx)
                }
                .frame(width: 13, height: 13)
                .foregroundStyle(.white)
                .padding(4)
                .background(overlayChrome, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.top, 10)
    }
}

@MainActor
func render() async {
    let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/bump-icons.png"
    let renderer = ImageRenderer(content: Sheet())
    renderer.scale = 2

    guard let image = renderer.cgImage else {
        FileHandle.standardError.write(Data("ImageRenderer produced no image\n".utf8))
        exit(1)
    }
    let url = URL(fileURLWithPath: output)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        FileHandle.standardError.write(Data("could not create \(output)\n".utf8))
        exit(1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        FileHandle.standardError.write(Data("could not write \(output)\n".utf8))
        exit(1)
    }
    print("wrote \(output) — \(BumpGlyph.allCases.count) glyphs")
}

await render()
