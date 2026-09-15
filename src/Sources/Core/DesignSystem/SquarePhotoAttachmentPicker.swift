import PhotosUI
import SwiftUI
import UIKit

/// Shared "add photos" control used by post creation and comments: lets the user take a
/// photo or choose from the library, then position each one into a 1:1 crop before it's
/// added to `images`. Callers only ever see finished square JPEG `Data`.
struct SquarePhotoAttachmentPicker<Content: View>: View {
    @Binding var images: [Data]
    var maxCount: Int = 6
    @ViewBuilder var label: () -> Content

    @State private var showingLibraryPicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var flowSeedImages: [UIImage] = []
    @State private var showingFlow = false

    private var remainingSlots: Int { max(0, maxCount - images.count) }

    var body: some View {
        Menu {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take photo", systemImage: "camera") {
                    flowSeedImages = []
                    showingFlow = true
                }
                .disabled(remainingSlots == 0)
            }
            Button("Choose from library", systemImage: "photo.on.rectangle") {
                showingLibraryPicker = true
            }
            .disabled(remainingSlots == 0)
        } label: {
            label()
        }
        .photosPicker(isPresented: $showingLibraryPicker, selection: $photoPickerItems, maxSelectionCount: max(1, remainingSlots), matching: .images)
        .onChange(of: photoPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                var loaded: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        loaded.append(image.normalizedOrientation())
                    }
                }
                photoPickerItems = []
                guard !loaded.isEmpty else { return }
                flowSeedImages = loaded
                showingFlow = true
            }
        }
        .fullScreenCover(isPresented: $showingFlow) {
            PhotoCropFlow(initialImages: flowSeedImages) { croppedData in
                images.append(contentsOf: croppedData)
                flowSeedImages = []
            }
        }
    }
}

/// Owns the camera → crop (→ crop again for multi-select) sequence behind a single
/// presentation so the parent never has to juggle more than one `fullScreenCover`.
private struct PhotoCropFlow: View {
    let onFinish: ([Data]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var queue: [UIImage]
    @State private var results: [Data] = []
    @State private var step: Step

    private enum Step {
        case camera
        case cropping(UIImage)
    }

    init(initialImages: [UIImage], onFinish: @escaping ([Data]) -> Void) {
        self.onFinish = onFinish
        if let first = initialImages.first {
            _queue = State(initialValue: Array(initialImages.dropFirst()))
            _step = State(initialValue: .cropping(first))
        } else {
            _queue = State(initialValue: [])
            _step = State(initialValue: .camera)
        }
    }

    var body: some View {
        Group {
            switch step {
            case .camera:
                CameraCaptureView(
                    onCapture: { image in step = .cropping(image.normalizedOrientation()) },
                    onCancel: { finish() }
                )
                .ignoresSafeArea()
            case .cropping(let image):
                SquareCropView(
                    image: image,
                    onConfirm: { data in
                        results.append(data)
                        advance()
                    },
                    onCancel: { advance() }
                )
            }
        }
    }

    private func advance() {
        if queue.isEmpty {
            finish()
        } else {
            step = .cropping(queue.removeFirst())
        }
    }

    private func finish() {
        onFinish(results)
        dismiss()
    }
}

/// The attachment strip's cell, shared by post creation and comment composition so the two
/// copies can't drift — they had already diverged on the remove button's padding.
///
/// The remove glyph keeps its corner position and size, but its tappable region is expanded
/// to `BumpHitTarget.min` rather than the ~20pt the glyph alone covered. Nothing underneath
/// is tappable, so the larger target has no taps to steal.
struct AttachmentThumbnail: View {
    let image: UIImage
    let size: CGFloat
    let onRemove: () -> Void

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: BumpRadius.small, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        // Deliberately darker than `overlayScrim`: this backs a white glyph
                        // over an arbitrary photo, where the job is legibility rather than
                        // the flat dimming that token is tuned for.
                        .foregroundStyle(.white, BumpColor.overlayChrome)
                        .padding(BumpSpacing.xs)
                        .frame(width: BumpHitTarget.min, height: BumpHitTarget.min, alignment: .topTrailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Remove photo"))
            }
    }
}
