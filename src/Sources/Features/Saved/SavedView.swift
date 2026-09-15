import SwiftUI

struct SavedView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: SavedViewModel?

    /// The server filters this list too, but blocking is queued: between the `202` and the
    /// consumer writing `Blocks`, `BlockedAccountSet` still returns the old set and a page
    /// can come back carrying the author just blocked. Same window the feed and search
    /// cover — it matters more here because `GET /Post/{id}` answers 404 for a hidden
    /// author, so a stale row dead-ends on an error screen rather than just lingering.
    private func visiblePosts(_ viewModel: SavedViewModel) -> [PostSummaryDto] {
        environment.blockStore.visible(viewModel.posts) { $0.accountId }
    }

    var body: some View {
        Group {
            if let viewModel {
                VStack(spacing: 0) {
                    // Chips, matching Search. A `.segmented` picker draws its own inset
                    // bordered track, which is the one small floating container this
                    // design language doesn't use anywhere else.
                    HStack(spacing: BumpSpacing.s) {
                        ForEach(SavedTab.allCases, id: \.self) { tab in
                            BumpChip(title: tab.titleKey, isSelected: viewModel.tab == tab) {
                                guard viewModel.tab != tab else { return }
                                HapticFeedback.selected()
                                viewModel.tab = tab
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, BumpSpacing.m)
                    .padding(.vertical, BumpSpacing.s)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(String(localized: "Saved filter"))
                    .background(BumpColor.surface)

                    switch viewModel.tab {
                    case .posts:
                        postsList(viewModel)
                    case .shops:
                        shopsList(viewModel)
                    }
                }
            } else {
                LoadingView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = SavedViewModel(saveService: environment.saveService, saveStore: environment.saveStore)
            }
            await viewModel?.loadIfNeeded()
        }
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func postsList(_ viewModel: SavedViewModel) -> some View {
        if viewModel.isLoadingPosts && viewModel.posts.isEmpty {
            LoadingView()
        } else if let errorMessage = viewModel.errorMessage, viewModel.posts.isEmpty {
            ErrorStateView(message: errorMessage) { Task { await viewModel.loadPosts() } }
        } else if visiblePosts(viewModel).isEmpty {
            EmptyStateView(
                icon: "bookmark",
                title: "Nothing saved yet",
                message: "Tap the bookmark on any post and it waits for you here."
            )
        } else {
            ScrollView {
                PostThumbnailGrid(posts: visiblePosts(viewModel)) { post in
                    Task { await viewModel.loadMorePostsIfNeeded(current: post) }
                }
            }
            .bumpPage()
            .refreshable { await viewModel.refresh() }
        }
    }

    @ViewBuilder
    private func shopsList(_ viewModel: SavedViewModel) -> some View {
        if viewModel.isLoadingShops && viewModel.shops.isEmpty {
            LoadingView()
        } else if let errorMessage = viewModel.errorMessage, viewModel.shops.isEmpty {
            ErrorStateView(message: errorMessage) { Task { await viewModel.loadShops() } }
        } else if viewModel.shops.isEmpty {
            EmptyStateView(
                icon: "bookmark",
                title: "No shops saved yet",
                message: "Save a place and you'll find it again in one tap."
            )
        } else {
            List {
                ForEach(viewModel.shops) { shop in
                    NavigationLink(value: AppRoute.shop(shop.id)) {
                        HStack(spacing: BumpSpacing.ms) {
                            RoundedRectangle(cornerRadius: BumpRadius.small, style: .continuous)
                                .fill(BumpColor.surfaceTertiary)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: "cup.and.saucer")
                                        .font(.system(size: BumpIconSize.small, weight: .light))
                                        .foregroundStyle(BumpColor.brand)
                                }
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                                Text(shop.name)
                                    .font(BumpFont.subheadline)
                                    .foregroundStyle(BumpColor.textPrimary)
                                    .lineLimit(1)
                                Text(shop.address)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(BumpColor.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: BumpSpacing.s)
                            RatingStarsView(rating: shop.rate.value)
                        }
                        .padding(.vertical, BumpSpacing.xs)
                        .accessibilityElement(children: .combine)
                    }
                    .listRowBackground(BumpColor.surface)
                    .listRowSeparatorTint(BumpColor.hairline)
                    .task { await viewModel.loadMoreShopsIfNeeded(current: shop) }
                    .swipeActions(edge: .trailing) {
                        Button("Unsave", systemImage: "bookmark.slash") {
                            Task {
                                await environment.saveStore.toggleShop(shop.id)
                                viewModel.removeSavedShop(shop.id)
                            }
                        }
                        .tint(.red)
                    }
                }
                if viewModel.isLoadingMoreShops {
                    ProgressView()
                        .tint(BumpColor.brand)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(BumpColor.surface)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .bumpScrollBackground()
            .refreshable { await viewModel.refresh() }
        }
    }
}
