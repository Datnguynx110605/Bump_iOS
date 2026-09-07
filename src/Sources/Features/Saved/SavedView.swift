import SwiftUI

struct SavedView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: SavedViewModel?

    var body: some View {
        Group {
            if let viewModel {
                VStack(spacing: 0) {
                    Picker("Saved filter", selection: Bindable(viewModel).tab) {
                        ForEach(SavedTab.allCases, id: \.self) { tab in
                            Text(tab.displayName).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, BumpSpacing.m)
                    .padding(.vertical, BumpSpacing.s)

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
        } else if viewModel.posts.isEmpty {
            EmptyStateView(
                icon: "bookmark.fill",
                title: String(localized: "No saved posts yet"),
                message: String(localized: "Tap the bookmark on a post to keep it here.")
            )
        } else {
            ScrollView {
                PostThumbnailGrid(posts: viewModel.posts) { post in
                    Task { await viewModel.loadMorePostsIfNeeded(current: post) }
                }
            }
            .background(BumpColor.surface)
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
                icon: "bookmark.fill",
                title: String(localized: "No saved shops yet"),
                message: String(localized: "Save a shop to find it again quickly.")
            )
        } else {
            List {
                ForEach(viewModel.shops) { shop in
                    NavigationLink(value: AppRoute.shop(shop.id)) {
                        HStack(spacing: BumpSpacing.ms) {
                            RoundedRectangle(cornerRadius: BumpRadius.small, style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .font(.footnote)
                                        .foregroundStyle(Color.accentColor)
                                }
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(shop.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BumpColor.textPrimary)
                                    .lineLimit(1)
                                Text(shop.address)
                                    .font(.caption)
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
                        .frame(maxWidth: .infinity)
                        .listRowBackground(BumpColor.surface)
                }
            }
            .listStyle(.plain)
            .bumpScrollBackground()
            .refreshable { await viewModel.refresh() }
        }
    }
}
