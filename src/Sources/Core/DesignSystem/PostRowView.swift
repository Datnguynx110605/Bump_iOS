import SwiftUI

/// The feed row — the app's signature surface.
///
/// **Full-bleed editorial.** There is no card: no border, no shadow, no rounded corner and
/// no inset. The photo runs the full width of the screen, the text rails sit on the page
/// itself, and one hairline at the bottom separates this post from the next. The photo is
/// the content; everything else is caption furniture around it.
///
/// Reading order is deliberate and matches how the row is actually scanned: *who* posted
/// it, *the photo*, *what you can do about it*, then *where it was and what they said*.
/// Putting the actions directly under the photo — rather than at the very bottom — keeps
/// them under the thumb on a phone and stops a long caption from pushing the like button
/// off the bottom of the visible area.
struct PostRowView: View {
    let item: PostFeedItemDto
    /// The feed's zoom namespace. `nil` where the row appears in a list that does not
    /// run the zoom transition, in which case the push is the ordinary one.
    var zoomNamespace: Namespace.ID? = nil
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var shop: ShopDto?
    @State private var displayedLikeCount: Int
    @State private var isLiked: Bool
    @State private var isSaved: Bool

    private var post: PostSummaryDto { item.post }

    init(item: PostFeedItemDto, zoomNamespace: Namespace.ID? = nil) {
        self.item = item
        self.zoomNamespace = zoomNamespace
        _displayedLikeCount = State(initialValue: item.post.reactionAmount.value)
        _isLiked = State(initialValue: item.isReacted)
        _isSaved = State(initialValue: item.isSaved)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Two navigation links rather than one wrapping the whole row: the action bar
            // sits between them, and nesting buttons inside a `NavigationLink` label makes
            // which one receives the tap ambiguous.
            NavigationLink(value: AppRoute.post(post.id)) {
                VStack(alignment: .leading, spacing: BumpSpacing.ms) {
                    AuthorRowView(accountId: post.accountId, trailingText: post.createdAt.relativeDescription)
                        .padding(.horizontal, BumpSpacing.m)

                    if !post.images.isEmpty {
                        PostImageCarousel(imageURLs: post.images.map(\.url))
                    }
                }
            }
            .buttonStyle(.bumpSurface)
            // Anchored to the author-plus-photo link rather than the whole row, so the
            // action bar and caption stay put while the photo grows into the detail
            // screen. Anchoring the outer stack would drag them into the zoom too.
            .zoomSource(zoomNamespace, id: AppRoute.post(post.id))

            // `s`, not `m`: the trailing save button centres a glyph inside a 44pt box,
            // so 8pt of padding is what puts the *glyph* on the same 16pt margin as the
            // caption underneath. The leading like label is wider than 44pt and so has no
            // centring slack of its own — it makes the difference up itself, below.
            actionBar
                .padding(.horizontal, BumpSpacing.s)

            NavigationLink(value: AppRoute.post(post.id)) {
                caption
                    .padding(.horizontal, BumpSpacing.m)
            }
            .buttonStyle(.bumpSurface)

            BumpDivider()
                .padding(.top, BumpSpacing.m)
        }
        .padding(.top, BumpSpacing.m)
        .task {
            environment.reactionStore.setLiked(post: post.id, isLiked)
            environment.saveStore.setSaved(post: post.id, isSaved)
            if shop == nil {
                shop = await environment.shopCache.shop(post.shopId)
            }
        }
        // `@State` seeded in `init` survives a feed reload, because SwiftUI keys it on the
        // row's identity and the post id hasn't changed — so without this the row keeps
        // showing the counts it was first built with.
        .onChange(of: item) { _, newItem in
            displayedLikeCount = newItem.post.reactionAmount.value
            isLiked = newItem.isReacted
            isSaved = newItem.isSaved
        }
    }

    /// Like, comment, save. Photo-adjacent and thumb-height.
    private var actionBar: some View {
        HStack(spacing: BumpSpacing.xs) {
            Button {
                Task {
                    let toggle = await environment.reactionStore.togglePost(post.id)
                    isLiked = toggle.isLiked
                    displayedLikeCount += toggle.countDelta
                    if toggle.countDelta > 0 { HapticFeedback.reacted() }
                }
            } label: {
                ReactionCountLabel(
                    glyph: .heart,
                    count: displayedLikeCount,
                    isActive: isLiked,
                    accessibilityLabel: String(localized: "Likes")
                )
            }
            .buttonStyle(.bumpIcon)
            .padding(.leading, BumpSpacing.s)
            .accessibilityLabel(isLiked ? String(localized: "Unlike") : String(localized: "Like"))
            .accessibilityValue(Text("\(displayedLikeCount)"))

            NavigationLink(value: AppRoute.post(post.id)) {
                ReactionCountLabel(
                    glyph: .comment,
                    count: post.commentAmount.value,
                    accessibilityLabel: String(localized: "Comments")
                )
            }
            .buttonStyle(.bumpIcon)

            Spacer()

            BumpToggleIconButton(
                isOn: isSaved,
                glyph: .bookmark,
                label: isSaved ? String(localized: "Remove from saved") : String(localized: "Save post")
            ) {
                Task { isSaved = await environment.saveStore.togglePost(post.id) }
            }
        }
    }

    /// Where it was, how it rated, what they said — the caption block under the actions.
    ///
    /// The address is dropped here because the feed is scanned rather than read; it lives
    /// on the post detail. The rating trails the shop name on the same line so the row has
    /// one text column rather than a left and a right edge fighting for attention.
    ///
    /// At accessibility text sizes the stars stop sharing that line. Five glyphs keep a
    /// fixed proportion of the width whatever the text size, so on one row the shop name
    /// is squeezed to "The Wo…" — the stars win a fight they shouldn't be in. Past
    /// `isAccessibilitySize` the name takes the full width and the rating sits under it.
    private var caption: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.xs) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                    shopNameText
                    RatingStarsView(rating: post.rate.value)
                }
            } else {
                HStack(spacing: BumpSpacing.xs) {
                    shopNameText
                    RatingStarsView(rating: post.rate.value)
                    Spacer(minLength: 0)
                }
            }

            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(BumpFont.callout)
                    .foregroundStyle(BumpColor.textSecondary)
                    .lineLimit(3)
                    .lineSpacing(BumpLeading.prose)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shopNameText: some View {
        Text(shop?.name ?? String(localized: "Finding the spot…"))
            .font(BumpFont.subheadline)
            .foregroundStyle(BumpColor.textPrimary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .redacted(reason: shop == nil ? .placeholder : [])
    }
}

private extension View {
    /// `matchedTransitionSource` needs a concrete namespace, so the optional is unwrapped
    /// here rather than at each call site.
    @ViewBuilder
    func zoomSource(_ namespace: Namespace.ID?, id: AppRoute) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
