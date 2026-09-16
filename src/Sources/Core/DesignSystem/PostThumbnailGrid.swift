import SwiftUI

/// Three-column square photo grid used by Profile, Shop detail, and Saved.
///
/// The gap is 2pt and the grid bleeds to the screen edges: in an editorial layout the
/// photos *are* the page, and inset, rounded tiles would reintroduce the floating-card
/// idiom the rest of the system just removed.
///
/// Cells size themselves with `aspectRatio` instead of a per-cell `GeometryReader`. The
/// GeometryReader version ran a measurement pass for every cell in a lazy grid and fed
/// its measured width into the image decode size, so the same photo could be decoded and
/// cached repeatedly at near-identical sizes.
struct PostThumbnailGrid: View {
    let posts: [PostSummaryDto]
    var onAppearOfLast: ((PostSummaryDto) -> Void)? = nil

    private static let spacing: CGFloat = 2
    private let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)

    /// One decode size for every cell, derived from the column width rather than
    /// measured per cell, so all thumbnails share cache entries.
    private static let decodeSize: CGSize = {
        let side = (UIScreen.main.bounds.width - spacing * 2) / 3
        return CGSize(width: side, height: side)
    }()

    var body: some View {
        LazyVGrid(columns: columns, spacing: Self.spacing) {
            ForEach(posts) { post in
                NavigationLink(value: AppRoute.post(post.id)) {
                    thumbnail(for: post)
                }
                .buttonStyle(.bumpSurface)
                .accessibilityLabel(String(localized: "Post"))
                .onAppear { onAppearOfLast?(post) }
            }
        }
    }

    /// A transparent square defines the cell, and the photo is overlaid and clipped into
    /// it. Sizing the image itself and hoping it lands square is what needs a
    /// `GeometryReader` per cell; this doesn't.
    private func thumbnail(for post: PostSummaryDto) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let url = post.images.first.flatMap({ URL(string: $0.url) }) {
                    CachedAsyncImage(url: url, targetSize: Self.decodeSize) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            BumpColor.fill
                        }
                    }
                } else {
                    // A text-only post still needs to read as a post rather than as a
                    // failed photo, so it gets the caption glyph on a tonal tile.
                    BumpColor.surfaceTertiary.overlay {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: BumpIconSize.small, weight: .light))
                            .foregroundStyle(BumpColor.textSecondary)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                // Multi-photo posts say so, the way every photo grid the user already
                // knows does. Without it a carousel is indistinguishable from a single
                // shot until you open it.
                if post.images.count > 1 {
                    // A white glyph sitting directly on an arbitrary photo has no
                    // guaranteed contrast. It gets an opaque chip rather than a soft dark
                    // halo — the same chip the carousel's counter uses, so every mark that
                    // sits on a photo in this app is the same solid espresso.
                    Image(systemName: "square.on.square")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(BumpColor.overlayChrome, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .padding(5)
                        .accessibilityHidden(true)
                }
            }
            .clipped()
            .contentShape(Rectangle())
    }
}
