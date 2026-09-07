import SwiftUI

/// Feed card. Photo-first: the carousel bleeds to the card's edges and the card itself
/// does the clipping, so the image reads as the content and the text rails around it.
struct PostRowView: View {
    let item: PostFeedItemDto
    @Environment(AppEnvironment.self) private var environment

    @State private var shop: ShopDto?
    @State private var displayedLikeCount: Int
    @State private var isLiked: Bool
    @State private var isSaved: Bool

    private var post: PostSummaryDto { item.post }

    init(item: PostFeedItemDto) {
        self.item = item
        _displayedLikeCount = State(initialValue: item.post.reactionAmount.value)
        _isLiked = State(initialValue: item.isReacted)
        _isSaved = State(initialValue: item.isSaved)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: AppRoute.post(post.id)) {
                cardContent
            }
            .buttonStyle(.plain)

            footer
                .padding(.horizontal, BumpSpacing.s)
                .padding(.bottom, BumpSpacing.xs)
        }
        .background(BumpColor.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BumpRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BumpRadius.card, style: .continuous)
                .strokeBorder(BumpColor.border, lineWidth: 1)
        )
        .task {
            environment.reactionStore.setLiked(post: post.id, isLiked)
            environment.saveStore.setSaved(post: post.id, isSaved)
            if shop == nil {
                shop = await environment.shopCache.shop(post.shopId)
            }
        }
        // `@State` seeded in `init` survives a feed reload, because SwiftUI keys it on the
        // row's identity and the post id hasn't changed — so without this the card keeps
        // showing the counts it was first built with.
        .onChange(of: item) { _, newItem in
            displayedLikeCount = newItem.post.reactionAmount.value
            isLiked = newItem.isReacted
            isSaved = newItem.isSaved
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                AuthorRowView(accountId: post.accountId)
                Spacer(minLength: BumpSpacing.s)
                Text(post.createdAt.relativeDescription)
                    .font(.caption)
                    .foregroundStyle(BumpColor.textSecondary)
            }
            .padding(.horizontal, BumpSpacing.m)
            .padding(.vertical, BumpSpacing.ms)

            if !post.images.isEmpty {
                PostImageCarousel(imageURLs: post.images.map(\.url), cornerRadius: 0)
            }

            VStack(alignment: .leading, spacing: BumpSpacing.s) {
                shopRow

                if let caption = post.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(BumpColor.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, BumpSpacing.m)
            .padding(.top, BumpSpacing.ms)
        }
    }

    /// Shop name and rating sit on one line as the card's subtitle; the address is
    /// dropped here because the feed is scanned, not read — it's on the post detail.
    private var shopRow: some View {
        HStack(spacing: BumpSpacing.xs) {
            Image(systemName: "mappin.circle.fill")
                .font(.footnote)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(shop?.name ?? String(localized: "Loading shop…"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BumpColor.textPrimary)
                .lineLimit(1)
                .redacted(reason: shop == nil ? .placeholder : [])

            Spacer(minLength: BumpSpacing.s)

            RatingStarsView(rating: post.rate.value)
        }
    }

    private var footer: some View {
        HStack(spacing: BumpSpacing.s) {
            Button {
                Task {
                    let toggle = await environment.reactionStore.togglePost(post.id)
                    isLiked = toggle.isLiked
                    displayedLikeCount += toggle.countDelta
                    if toggle.countDelta > 0 { HapticFeedback.reacted() }
                }
            } label: {
                ReactionCountLabel(
                    systemImage: isLiked ? "heart.fill" : "heart",
                    count: displayedLikeCount,
                    isActive: isLiked,
                    accessibilityLabel: String(localized: "Likes")
                )
            }
            .buttonStyle(.bumpIcon)
            .accessibilityLabel(isLiked ? String(localized: "Unlike") : String(localized: "Like"))
            .accessibilityValue(Text("\(displayedLikeCount)"))

            NavigationLink(value: AppRoute.post(post.id)) {
                ReactionCountLabel(
                    systemImage: "bubble.right",
                    count: post.commentAmount.value,
                    accessibilityLabel: String(localized: "Comments")
                )
            }
            .buttonStyle(.bumpIcon)

            Spacer()

            BumpToggleIconButton(
                isOn: isSaved,
                onImage: "bookmark.fill",
                offImage: "bookmark",
                label: isSaved ? String(localized: "Remove from saved") : String(localized: "Save post")
            ) {
                Task { isSaved = await environment.saveStore.togglePost(post.id) }
            }
        }
    }
}
