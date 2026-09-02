import SwiftUI

/// Square, horizontally-scrollable image carousel shared by feed rows, post detail,
/// and comment images so multi-photo posts/comments all page the same way.
struct PostImageCarousel: View {
    let imageURLs: [String]
    @State private var scrollPositionID: Int?

    private var currentIndex: Int { scrollPositionID ?? 0 }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, urlString in
                        CachedAsyncImage(url: URL(string: urlString), targetSize: CGSize(width: proxy.size.width, height: proxy.size.width)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .empty:
                                Rectangle().fill(BumpColor.fill).overlay(ProgressView())
                            case .failure:
                                Rectangle().fill(BumpColor.fill)
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
            .scrollPosition(id: $scrollPositionID)
            .scrollIndicators(.hidden)
            .scrollDisabled(imageURLs.count <= 1)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: BumpRadius.card))
        .overlay(alignment: .bottom) {
            if imageURLs.count > 1 {
                pageDots
            }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(imageURLs.indices, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, BumpSpacing.xs)
        .padding(.horizontal, BumpSpacing.s)
        .background(.black.opacity(0.25), in: Capsule())
        .padding(.bottom, BumpSpacing.s)
        .accessibilityHidden(true)
    }
}
