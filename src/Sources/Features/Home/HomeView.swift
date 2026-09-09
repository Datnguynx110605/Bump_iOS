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

    var body: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            LoadingView()
        } else if let errorMessage = viewModel.errorMessage, viewModel.posts.isEmpty {
            ErrorStateView(message: errorMessage) { Task { await viewModel.refreshAll() } }
        } else {
            List {
                NearbySection(viewModel: viewModel)

                if viewModel.posts.isEmpty {
                    EmptyStateView(
                        icon: "person.2.fill",
                        title: String(localized: "Your feed is quiet"),
                        message: String(localized: "Bump fills this with posts from people you follow and places you've reacted to. Find a few to get started."),
                        actionTitle: String(localized: "Discover Shops & People"),
                        action: onDiscover
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.posts) { item in
                        PostRowView(item: item)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: BumpSpacing.s, leading: BumpSpacing.m, bottom: BumpSpacing.s, trailing: BumpSpacing.m))
                            .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BumpSpacing.m)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .bumpScrollBackground()
            .refreshable { await viewModel.refreshAll() }
        }
    }
}

// MARK: - Nearby

private struct NearbySection: View {
    let viewModel: HomeViewModel

    var body: some View {
        Section {
            content
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: BumpSpacing.xs, leading: 0, bottom: BumpSpacing.s, trailing: 0))
        } header: {
            Label("Top Rated Nearby", systemImage: "location.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BumpColor.textPrimary)
                .textCase(nil)
                .padding(.horizontal, BumpSpacing.m)
                .listRowInsets(EdgeInsets())
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.nearby {
        case .needsPermission:
            NearbyNoticeCard(
                icon: "location.circle.fill",
                title: String(localized: "See the best spots around you"),
                message: String(localized: "Share your location and Bump shows the top-rated shops within five kilometres."),
                actionTitle: String(localized: "Use My Location"),
                tone: .brand
            ) {
                Task { await viewModel.loadNearby() }
            }

        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 96)

        case .locationOff:
            NearbyNoticeCard(
                icon: "location.slash.fill",
                title: String(localized: "Location is off"),
                message: String(localized: "Turn location on in Settings to see top-rated shops near you."),
                actionTitle: String(localized: "Open Settings"),
                tone: .muted
            ) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }

        case .failed:
            NearbyNoticeCard(
                icon: "exclamationmark.triangle.fill",
                title: String(localized: "Couldn't find shops nearby"),
                message: String(localized: "Check your connection and try again."),
                actionTitle: String(localized: "Try Again"),
                tone: .muted
            ) {
                Task { await viewModel.loadNearby() }
            }

        case .loaded(let shops):
            if shops.isEmpty {
                NearbyNoticeCard(
                    icon: "mappin.slash",
                    title: String(localized: "Nothing highly rated yet"),
                    message: String(localized: "No shop near you has cleared four stars. Be the first to post one."),
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

private struct NearbyShopCard: View {
    let rank: Int
    let shop: ShopSummaryDto

    /// Scales with Dynamic Type so a longer text size widens the card instead of
    /// truncating a shop name to nothing.
    @ScaledMetric private var cardWidth: CGFloat = 216

    var body: some View {
        NavigationLink(value: AppRoute.shop(shop.id)) {
            VStack(alignment: .leading, spacing: BumpSpacing.s) {
                HStack(spacing: BumpSpacing.s) {
                    RankBadge(rank: rank)
                    Spacer(minLength: 0)
                    RatingStarsView(rating: shop.rate.value)
                }

                VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                    Text(shop.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BumpColor.textPrimary)
                        .lineLimit(2)
                    Text(shop.address)
                        .font(.caption)
                        .foregroundStyle(BumpColor.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .bumpCard()
            .frame(width: cardWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Number \(rank) nearby, \(shop.name), \(shop.address), rated \(shop.rate.value) out of 5"))
        .accessibilityAddTraits(.isButton)
    }
}

private struct RankBadge: View {
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(minWidth: 22, minHeight: 22)
            .background(BumpColor.brandFill, in: Circle())
            .accessibilityHidden(true)
    }
}

/// One shape for every non-list state of the nearby section, so permission, failure and
/// "nothing found" read as the same designed component rather than three ad-hoc blocks.
private struct NearbyNoticeCard: View {
    enum Tone {
        case brand
        case muted
    }

    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var tone: Tone = .muted
    var action: (() -> Void)?

    @ScaledMetric private var iconSize: CGFloat = BumpIconSize.medium

    var body: some View {
        HStack(alignment: .top, spacing: BumpSpacing.ms) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BumpColor.textPrimary)
                Text(message)
                    .font(.caption)
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
