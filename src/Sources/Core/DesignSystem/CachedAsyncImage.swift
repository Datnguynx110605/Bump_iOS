import SwiftUI
import ImageIO
import UIKit

final class ImageDecodeCache {
    static let shared = ImageDecodeCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.totalCostLimit = 150 * 1024 * 1024 }

    func image(for key: String) -> UIImage? { cache.object(forKey: key as NSString) }

    func store(_ image: UIImage, for key: String) {
        let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

enum CachedImagePhase {
    case empty
    case success(Image)
    case failure
}

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    var targetSize: CGSize
    @ViewBuilder var content: (CachedImagePhase) -> Content
    @Environment(\.displayScale) private var displayScale

    @State private var phase: CachedImagePhase = .empty

    var body: some View {
        if let cached = ImageDecodeCache.shared.image(for: cacheKey) {
            content(.success(Image(uiImage: cached)))
        } else {
            content(phase)
                .task(id: url) {
                    await load()
                }
        }
    }

    private var cacheKey: String {
        guard let url else { return "" }
        let maxPixelSize = max(targetSize.width, targetSize.height) * displayScale
        return "\(url.absoluteString)#\(Int(maxPixelSize))"
    }

    private func load() async {
        guard let url else { phase = .empty; return }
        let maxPixelSize = max(targetSize.width, targetSize.height) * displayScale
        let key = cacheKey

        guard let image = await Self.downsample(url: url, maxPixelSize: maxPixelSize) else {
            if !Task.isCancelled { phase = .failure }
            return
        }
        ImageDecodeCache.shared.store(image, for: key)
        if !Task.isCancelled {
            phase = .success(Image(uiImage: image))
        }
    }

    private static func downsample(url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return UIImage(cgImage: cgImage)
        }.value
    }
}
