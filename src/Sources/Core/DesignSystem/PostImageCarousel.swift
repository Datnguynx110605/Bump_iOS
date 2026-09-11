import SwiftUI

/// Square, horizontally-paged image carousel shared by feed rows, post detail, and
/// comment images so multi-photo posts and comments all page the same way.
///
/// Pages are sized from a measured width, but photos are always *decoded* at one fixed
/// size. Feeding the measured width into the decode target — as this did before — makes
/// the decode cache key vary with layout, so the same photo gets downsampled and cached
/// more than once.
struct PostImageCarousel: View {
    let imageURLs: [String]
    /// 0 when the carousel bleeds to the edges of a card that does its own clipping.
    var cornerRadius: CGFloat = BumpRadius.card
    @State private var currentIndex: Int?

    private var pageIndex: Int { currentIndex ?? 0 }

    var body: some View {
        // The pages need the carousel's own width, and that width differs per host (a
        // feed card is inset, post detail is not), so it has to be measured. What the
        // GeometryReader no longer feeds is the *decode* size — that's fixed below, so
        // the same photo can't land in the decode cache several times over under
        // near-identical measured widths.
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, urlString in
                        CachedAsyncImage(url: URL(string: urlString), targetSize: Self.decodeSize) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .empty:
                                BumpColor.fill.overlay(ProgressView())
                            case .failure:
                                BumpColor.fill.overlay(
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundStyle(BumpColor.textTertiary)
                                )
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.width)
                        .clipped()
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $currentIndex)
            .scrollIndicators(.hidden)
            .scrollDisabled(imageURLs.count <= 1)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if imageURLs.count > 1 {
                pageCounter
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            imageURLs.count > 1
                ? String(localized: "\(imageURLs.count) photos")
                : String(localized: "Photo")
        )
    }

    /// A feed photo is drawn at roughly full screen width; one fixed decode size keeps a
    /// single cache entry per photo instead of one per measured row width.
    private static let decodeSize: CGSize = {
        let side = UIScreen.main.bounds.width
        return CGSize(width: side, height: side)
    }()

    /// A numeric badge instead of a dot row: it stays legible past three photos, needs no
    /// per-dot views, and reads correctly at large Dynamic Type sizes.
    private var pageCounter: some View {
        Text("\(pageIndex + 1)/\(imageURLs.count)")
            .font(.caption2.weight(.semibold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.vertical, BumpSpacing.xs)
            .padding(.horizontal, BumpSpacing.s)
            .background(BumpColor.overlayChrome, in: Capsule())
            .padding(BumpSpacing.s)
            .accessibilityHidden(true)
    }
}
