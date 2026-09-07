import SwiftUI

/// Three-column square photo grid used by Profile, Shop detail, and Saved.
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
                .buttonStyle(.plain)
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
                    BumpColor.fill.overlay {
                        Image(systemName: "text.bubble")
                            .foregroundStyle(BumpColor.textTertiary)
                    }
                }
            }
            .clipped()
            .contentShape(Rectangle())
    }
}
