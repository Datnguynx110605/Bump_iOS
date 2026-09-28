import SwiftUI
import UIKit

/// The app's landing screen: a personalized feed of posts from accounts the viewer
/// follows or has reacted to, headed by top-rated shops near them.
///
/// The two halves are deliberate. `/Post/related` matches only on followings and
/// reaction affinity, so a brand-new account has an empty feed and no global fallback
/// exists any more — the nearby strip and the discovery empty state are what make the
/// first launch a usable screen rather than a blank one.
struct HomeView: View {
    /// Sends the viewer to Search, which is a sibling tab rather than a push, so the
    /// switch is owned by `MainTabView`.
    let onDiscover: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: HomeViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    HomeListView(viewModel: viewModel, onDiscover: onDiscover)
                        .autoRefresh(every: .seconds(60)) { await viewModel.refreshIfStale() }
                } else {
                    LoadingView()
                }
            }
            .navigationTitle("Bump")
            .appRouteDestinations()
        }
        .task {
            if viewModel == nil {
                viewModel = HomeViewModel(
                    postService: environment.postService,
                    shopService: environment.shopService,
                    locationProvider: environment.locationProvider
                )
            }
            await viewModel?.loadInitialIfNeeded()
        }
        .onChange(of: environment.feedRefreshSignal.version) { _, _ in
            Task { await viewModel?.reload() }
        }
    }
}

private struct HomeListView: View {
    let viewModel: HomeViewModel
    let onDiscover: () -> Void
    @Environment(AppEnvironment.self) private var environment

    /// Blocking is queued server-side, so the page already on screen still contains the
    /// blocked author's posts until the consumer runs and the cache signature changes.
    /// Dropping them here is what makes "Block" look like it did something.
    private var visiblePosts: [PostFeedItemDto] {
        environment.blockStore.visible(viewModel.posts) { $0.post.accountId }
    }

    var body: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            // A feed has a known shape, so it waits as a skeleton of that shape rather
            // than as a spinner — the layout doesn't jump when posts land, and the wait
            // reads as "loading your feed" instead of "loading something".
            ScrollView {
                VStack(spacing: 0) {
                    NearbySection(viewModel: viewModel)
                    BumpSkeletonList()
                }
            }
            .bumpPage()
        } else if let errorMessage = viewModel.errorMessage, viewModel.posts.isEmpty {
            ErrorStateView(message: errorMessage) { Task { await viewModel.refreshAll() } }
        } else {
            // A `ScrollView`, not a `List`. `List` decorates every `NavigationLink`
            // inside a row with its own trailing disclosure chevron, and a feed row holds
            // three of them — one landed in the middle of the action bar, between the
            // comment and save buttons. The row already draws its own hairline and bleeds
            // to both edges, so the only thing `List` still contributed was
            // `.refreshable`, which `ScrollView` supports directly.
            ScrollView {
                LazyVStack(spacing: 0) {
                    NearbySection(viewModel: viewModel)

                    if visiblePosts.isEmpty {
                        EmptyStateView(
                            glyph: .sparkle,
                            title: "Your feed is quiet",
                            message: "Follow a few people and react to the places you like — their posts land here.",
                            actionTitle: "Find shops & people",
                            action: onDiscover
                        )
                        .frame(minHeight: 380)
                        // `isNearEnd` uses a window precisely so a filtered *row* still
                        // pages, but when every post in every loaded page is from a
                        // blocked author the `ForEach` renders nothing at all, and the
                        // paging trigger goes with it — the feed stops here for good while
                        // the server still has pages. Keyed on the loaded count so it
                        // drains page after page until a visible post arrives or the
                        // server runs out.
                        .task(id: viewModel.posts.count) {
                            guard let last = viewModel.posts.last else { return }
                            await viewModel.loadMoreIfNeeded(currentItem: last)
                        }
                    } else {
                        ForEach(visiblePosts) { item in
                            PostRowView(item: item)
                                .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                        }

                        if viewModel.isLoadingMore {
                            ProgressView()
                                .tint(BumpColor.brand)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BumpSpacing.l)
                        }
                    }
                }
            }
            .bumpPage()
            .refreshable { await viewModel.refreshAll() }
        }
    }
}

// MARK: - Nearby

/// The discovery strip above the feed: the highest-rated shops within range, ranked.
///
/// Headed by the system's editorial section label rather than a boxed header, and the
/// strip itself scrolls horizontally with the same full-bleed logic as the feed — the
/// cards run off the right edge of the screen instead of stopping at a margin, which is
/// what tells the user there is more to swipe to.
private struct NearbySection: View {
    let viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.ms) {
            BumpSectionHeader("Nearby & highly rated")
                .padding(.top, BumpSpacing.s)

            content

            BumpDivider()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.nearby {
        case .needsPermission:
            NearbyNotice(
                glyph: .location,
                title: "See the best spots around you",
                message: "Share your location and Bump shows the top-rated shops within five kilometres.",
                actionTitle: "Use my location",
                tone: .brand
            ) {
                Task { await viewModel.loadNearby() }
            }

        case .loading:
            HStack(spacing: BumpSpacing.ms) {
                ForEach(0..<2, id: \.self) { _ in
                    BumpSkeletonBlock(width: 240, height: 108, cornerRadius: BumpRadius.card)
                }
            }
            .padding(.horizontal, BumpSpacing.m)

        case .locationOff:
            NearbyNotice(
                glyph: .location, variant: .slashed,
                title: "Location is off",
                message: "Turn location on in Settings to see top-rated shops near you.",
                actionTitle: "Open Settings",
                tone: .muted
            ) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }

        case .failed:
            NearbyNotice(
                glyph: .warning,
                title: "Couldn't find shops nearby",
                message: "Check your connection and try again.",
                actionTitle: "Try again",
                tone: .muted
            ) {
                Task { await viewModel.loadNearby() }
            }

        case .loaded(let shops):
            if shops.isEmpty {
                NearbyNotice(
                    glyph: .mappin, variant: .slashed,
                    title: "Nothing highly rated yet",
                    message: "No shop near you has cleared four stars. Be the first to post one.",
                    actionTitle: nil,
                    tone: .muted,
                    action: nil
                )
            } else {
                NearbyCarousel(shops: shops)
            }
        }
    }
}

private struct NearbyCarousel: View {
    let shops: [ShopSummaryDto]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: BumpSpacing.ms) {
                ForEach(Array(shops.enumerated()), id: \.element.id) { index, shop in
                    NearbyShopCard(rank: index + 1, shop: shop)
                }
            }
            .padding(.horizontal, BumpSpacing.m)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
    }
}

/// One shop in the nearby strip.
///
/// The rank is set as a large editorial numeral rather than stuffed into a badge: at a
/// glance the user reads "1, 2, 3" down the strip, and the numeral doubles as the tile's
/// visual anchor on a surface that has no border to hold it together.
private struct NearbyShopCard: View {
    let rank: Int
    let shop: ShopSummaryDto

    /// Scales with Dynamic Type so a longer text size widens the tile instead of
    /// truncating a shop name to nothing.
    @ScaledMetric private var cardWidth: CGFloat = 240

    var body: some View {
        NavigationLink(value: AppRoute.shop(shop.id)) {
            HStack(alignment: .top, spacing: BumpSpacing.ms) {
                Text("\(rank)")
                    .font(BumpFont.display)
                    .foregroundStyle(BumpColor.brandFaint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                    Text(shop.name)
                        .font(BumpFont.subheadline)
                        .foregroundStyle(BumpColor.textPrimary)
                        .lineLimit(2)
                    Text(shop.address)
                        .font(BumpFont.meta)
                        .foregroundStyle(BumpColor.textSecondary)
                        .lineLimit(2)
                    RatingStarsView(rating: shop.rate.value)
                        .padding(.top, BumpSpacing.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .bumpCard()
            .frame(width: cardWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bumpSurface)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Number \(rank) nearby, \(shop.name), \(shop.address), rated \(shop.rate.value) out of 5"))
        .accessibilityAddTraits(.isButton)
    }
}

/// One shape for every non-list state of the nearby section, so permission, failure and
/// "nothing found" read as the same designed component rather than three ad-hoc blocks.
///
/// Flat and inset rather than carded: on a page with no elevation, a notice earns its
/// separation from a tonal step, and the light-weight outline glyph keeps it from
/// shouting louder than the shops it stands in for.
private struct NearbyNotice: View {
    enum Tone {
        case brand
        case muted
    }

    let glyph: BumpGlyph
    var variant: BumpGlyphVariant = .outline
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var tone: Tone = .muted
    var action: (() -> Void)?

    @ScaledMetric private var iconSize: CGFloat = BumpIconSize.medium

    var body: some View {
        HStack(alignment: .top, spacing: BumpSpacing.ms) {
            BumpIcon(glyph, variant, size: iconSize)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                Text(title)
                    .font(BumpFont.subheadline)
                    .foregroundStyle(BumpColor.textPrimary)
                Text(message)
                    .font(BumpFont.meta)
                    .foregroundStyle(BumpColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.bumpText)
                }
            }
            Spacer(minLength: 0)
        }
        .bumpCard()
        .padding(.horizontal, BumpSpacing.m)
    }

    private var tint: Color {
        switch tone {
        case .brand: BumpColor.brand
        case .muted: BumpColor.textSecondary
        }
    }
}
