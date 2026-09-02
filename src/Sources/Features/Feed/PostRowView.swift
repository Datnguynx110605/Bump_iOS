import SwiftUI

struct PostRowView: View {
    let item: PostFeedItemDto
    @Environment(AppEnvironment.self) private var environment

    @State private var shop: ShopDto?
    @State private var displayedLikeCount: Int
    @State private var isLiked: Bool
    @State private var isSaved: Bool
    @ScaledMetric private var bookmarkIconSize: CGFloat = BumpIconSize.medium

    private var post: PostSummaryDto { item.post }

    init(item: PostFeedItemDto) {
        self.item = item
        _displayedLikeCount = State(initialValue: item.post.reactionAmount.value)
        _isLiked = State(initialValue: item.isReacted)
        _isSaved = State(initialValue: item.isSaved)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.s) {
            NavigationLink(value: AppRoute.post(post.id)) {
                cardContent
            }
            .buttonStyle(.plain)

            footer
        }
        .padding(BumpSpacing.m)
        .background(BumpColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: BumpRadius.card))
        .task {
            environment.reactionStore.setLiked(post: post.id, isLiked)
            environment.saveStore.setSaved(post: post.id, isSaved)
            if shop == nil {
                shop = await environment.shopCache.shop(post.shopId)
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.s) {
            HStack {
                AuthorRowView(accountId: post.accountId)
                Spacer()
                Text(post.createdAt.relativeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            shopRow

            if !post.images.isEmpty {
                PostImageCarousel(imageURLs: post.images.map(\.url))
            }

            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.subheadline)
                    .lineLimit(3)
                    .foregroundStyle(.primary)
            }
        }
    }

    private var shopRow: some View {
        HStack(spacing: BumpSpacing.xs) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.secondary)
            Text(shop?.name ?? String(localized: "Loading shop…"))
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .layoutPriority(1)
                .redacted(reason: shop == nil ? .placeholder : [])
            if let address = shop?.address {
                Text("· \(address)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: BumpSpacing.xs)
            RatingStarsView(rating: post.rate.value, size: 11)
        }
    }

    private var footer: some View {
        HStack(spacing: BumpSpacing.l) {
            Button {
                Task {
                    let liked = await environment.reactionStore.togglePost(post.id)
                    isLiked = liked
                    displayedLikeCount += liked ? 1 : -1
                    if liked {
                        HapticFeedback.reacted()
                    }
                }
            } label: {
                ReactionCountLabel(systemImage: isLiked ? "heart.fill" : "heart", count: displayedLikeCount, isActive: isLiked)
            }
            .buttonStyle(.plain)

            ReactionCountLabel(systemImage: "bubble.right", count: post.commentAmount.value)

            Spacer()

            Button {
                Task { isSaved = await environment.saveStore.togglePost(post.id) }
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: bookmarkIconSize))
                    .foregroundStyle(isSaved ? Color.accentColor : BumpColor.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }
}
