import SwiftUI

struct PostThumbnailGrid: View {
    let posts: [PostSummaryDto]
    var onAppearOfLast: ((PostSummaryDto) -> Void)? = nil

    private let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(posts) { post in
                NavigationLink(value: AppRoute.post(post.id)) {
                    thumbnail(for: post)
                }
                .buttonStyle(.plain)
                .onAppear { onAppearOfLast?(post) }
            }
        }
    }

    @ViewBuilder
    private func thumbnail(for post: PostSummaryDto) -> some View {
        GeometryReader { proxy in
            if let url = post.images.first.flatMap({ URL(string: $0.url) }) {
                CachedAsyncImage(url: url, targetSize: CGSize(width: proxy.size.width, height: proxy.size.width)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(Color(.tertiarySystemFill))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.width)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: proxy.size.width, height: proxy.size.width)
                    .overlay {
                        Image(systemName: "text.bubble")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
