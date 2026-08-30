import SwiftUI
import UIKit

/// Lets the user pinch-zoom and drag-pan a photo to position it inside a fixed 1:1 frame,
/// then exports exactly what's visible in that frame as a square JPEG.
struct SquareCropView: View {
    let image: UIImage
    let onConfirm: (Data) -> Void
    let onCancel: () -> Void

    @State private var gestureScale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var dragTranslation: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero
    @State private var containerSize: CGSize = .zero

    private let maxScale: CGFloat = 5
    private let exportSide: CGFloat = 1440

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Color.black
                    .onAppear { containerSize = proxy.size }
                    .onChange(of: proxy.size) { _, newValue in containerSize = newValue }
                    .overlay(cropCanvas(containerSize: proxy.size))
            }
            .background(Color.black)
            .navigationTitle("Position Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo", action: confirm)
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func cropCanvas(containerSize: CGSize) -> some View {
        let frameSide = min(containerSize.width, containerSize.height)
        let fit = fitScale(frameSide: frameSide)
        let totalScale = fit * currentScale
        let displaySize = CGSize(width: pixelSize.width * totalScale, height: pixelSize.height * totalScale)

        ZStack {
            Image(uiImage: image)
                .resizable()
                .frame(width: displaySize.width, height: displaySize.height)
                .offset(currentOffset)
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .contentShape(Rectangle())
        .clipShape(Rectangle())
        .mask(Rectangle().frame(width: frameSide, height: frameSide))
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.85), lineWidth: 1)
                .frame(width: frameSide, height: frameSide)
                .allowsHitTesting(false)
        )
        .gesture(
            SimultaneousGesture(dragGesture(frameSide: frameSide, fit: fit), magnificationGesture(frameSide: frameSide, fit: fit))
        )
    }

    private var pixelSize: CGSize {
        if let cgImage = image.cgImage {
            return CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        }
        return image.size
    }

    private var currentScale: CGFloat { steadyScale * gestureScale }
    private var currentOffset: CGSize {
        CGSize(width: steadyOffset.width + dragTranslation.width, height: steadyOffset.height + dragTranslation.height)
    }

    private func fitScale(frameSide: CGFloat) -> CGFloat {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return 1 }
        return max(frameSide / pixelSize.width, frameSide / pixelSize.height)
    }

    private func clampedOffset(_ proposed: CGSize, frameSide: CGFloat, fit: CGFloat, scale: CGFloat) -> CGSize {
        let totalScale = fit * scale
        let displaySize = CGSize(width: pixelSize.width * totalScale, height: pixelSize.height * totalScale)
        let maxX = max(0, (displaySize.width - frameSide) / 2)
        let maxY = max(0, (displaySize.height - frameSide) / 2)
        return CGSize(width: min(max(proposed.width, -maxX), maxX), height: min(max(proposed.height, -maxY), maxY))
    }

    private func dragGesture(frameSide: CGFloat, fit: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragTranslation = value.translation
            }
            .onEnded { value in
                let proposed = CGSize(width: steadyOffset.width + value.translation.width,
                                       height: steadyOffset.height + value.translation.height)
                steadyOffset = clampedOffset(proposed, frameSide: frameSide, fit: fit, scale: currentScale)
                dragTranslation = .zero
            }
    }

    private func magnificationGesture(frameSide: CGFloat, fit: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                gestureScale = max(1 / max(steadyScale, 0.001), min(value, maxScale / max(steadyScale, 1)))
            }
            .onEnded { value in
                steadyScale = max(1, min(steadyScale * value, maxScale))
                gestureScale = 1
                steadyOffset = clampedOffset(steadyOffset, frameSide: frameSide, fit: fit, scale: steadyScale)
            }
    }

    private func confirm() {
        let frameSide = min(containerSize.width, containerSize.height)
        guard frameSide > 0 else { onConfirm(image.jpegData(compressionQuality: 0.85) ?? Data()); return }

        let fit = fitScale(frameSide: frameSide)
        let totalScale = fit * currentScale
        let displaySize = CGSize(width: pixelSize.width * totalScale, height: pixelSize.height * totalScale)

        let cropOrigin = CGPoint(
            x: (displaySize.width - frameSide) / 2 - currentOffset.width,
            y: (displaySize.height - frameSide) / 2 - currentOffset.height
        )
        let originPixels = CGPoint(x: cropOrigin.x / totalScale, y: cropOrigin.y / totalScale)
        let sidePixels = frameSide / totalScale
        let cropRect = CGRect(x: originPixels.x, y: originPixels.y, width: sidePixels, height: sidePixels)
            .intersection(CGRect(origin: .zero, size: pixelSize))

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: exportSide, height: exportSide))
        let data = renderer.jpegData(withCompressionQuality: 0.85) { _ in
            if let cgImage = image.cgImage, let cropped = cgImage.cropping(to: cropRect) {
                UIImage(cgImage: cropped).draw(in: CGRect(x: 0, y: 0, width: exportSide, height: exportSide))
            } else {
                image.draw(in: CGRect(x: 0, y: 0, width: exportSide, height: exportSide))
            }
        }
        onConfirm(data)
    }
}
