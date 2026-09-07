import SwiftUI
import ImageIO
import UIKit

/// Decoded-bitmap cache sitting in front of `URLCache`. `URLCache` saves the download;
/// this saves the far more expensive JPEG decode + downsample on every scroll pass.
///
/// The cost limit is deliberately modest: these are fully decoded bitmaps, they stack on
/// top of `URLCache`'s in-memory allotment, and an oversized limit is what gets a
/// photo feed jetsammed on older devices. The cache is also dropped wholesale on a
/// memory warning, since every entry can be rebuilt from disk.
final class ImageDecodeCache {
    static let shared = ImageDecodeCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.totalCostLimit = 48 * 1024 * 1024
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [cache] _ in
            cache.removeAllObjects()
        }
    }

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

/// Downsampling remote image view. Decodes to roughly the size it will be drawn at
/// rather than the source's full resolution, which is what keeps a scrolling feed of
/// 1440px photos off the memory ceiling.
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    var targetSize: CGSize
    @ViewBuilder var content: (CachedImagePhase) -> Content
    @Environment(\.displayScale) private var displayScale

    @State private var phase: CachedImagePhase = .empty

    var body: some View {
        // One branch, always. Reading the cache inside an `if` that swaps between two
        // different subtrees changes structural identity as soon as the image lands,
        // which makes SwiftUI tear down and rebuild the view mid-scroll.
        content(resolvedPhase)
            .task(id: cacheKey) { await load() }
    }

    /// A hit in the decode cache short-circuits the placeholder entirely, so a
    /// previously-seen photo paints on the first frame instead of flashing empty.
    private var resolvedPhase: CachedImagePhase {
        if case .empty = phase, let cached = ImageDecodeCache.shared.image(for: cacheKey) {
            return .success(Image(uiImage: cached))
        }
        return phase
    }

    private var maxPixelSize: CGFloat {
        max(targetSize.width, targetSize.height) * displayScale
    }

    private var cacheKey: String {
        guard let url else { return "" }
        return "\(url.absoluteString)#\(Int(maxPixelSize))"
    }

    private func load() async {
        guard let url else { return }
        let key = cacheKey
        if ImageDecodeCache.shared.image(for: key) != nil { return }

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
