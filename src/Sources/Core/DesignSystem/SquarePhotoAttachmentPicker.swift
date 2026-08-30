import PhotosUI
import SwiftUI
import UIKit

private struct CropCandidate: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Shared "add photos" control used by post creation and comments: lets the user take a
/// photo or choose from the library, then position each one into a 1:1 crop before it's
/// added to `images`. Callers only ever see finished square JPEG `Data`.
struct SquarePhotoAttachmentPicker<Content: View>: View {
    @Binding var images: [Data]
    var maxCount: Int = 6
    @ViewBuilder var label: () -> Content

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var cropQueue: [CropCandidate] = []
    @State private var showingCamera = false

    private var remainingSlots: Int { max(0, maxCount - images.count - cropQueue.count) }

    var body: some View {
        Menu {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo", systemImage: "camera") { showingCamera = true }
                    .disabled(remainingSlots == 0)
            }
            PhotosPicker(selection: $photoPickerItems, maxSelectionCount: max(1, remainingSlots), matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
            .disabled(remainingSlots == 0)
        } label: {
            label()
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCaptureView(
                onCapture: { image in
                    showingCamera = false
                    cropQueue.append(CropCandidate(image: image))
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(item: currentCandidate) { candidate in
            SquareCropView(
                image: candidate.image,
                onConfirm: { data in
                    images.append(data)
                    advanceQueue()
                },
                onCancel: { advanceQueue() }
            )
        }
        .onChange(of: photoPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        cropQueue.append(CropCandidate(image: image))
                    }
                }
                photoPickerItems = []
            }
        }
    }

    private var currentCandidate: Binding<CropCandidate?> {
        Binding(get: { cropQueue.first }, set: { newValue in
            if newValue == nil { advanceQueue() }
        })
    }

    private func advanceQueue() {
        if !cropQueue.isEmpty { cropQueue.removeFirst() }
    }
}
