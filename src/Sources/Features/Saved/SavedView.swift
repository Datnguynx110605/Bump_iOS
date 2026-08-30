import SwiftUI

struct SavedView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: SavedViewModel?

    var body: some View {
        Group {
            if let viewModel {
                VStack(spacing: 0) {
                    Picker("", selection: Bindable(viewModel).tab) {
                        ForEach(SavedTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(BumpSpacing.m)

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
            EmptyStateView(icon: "bookmark", title: "No saved posts yet")
        } else {
            ScrollView {
                PostThumbnailGrid(posts: viewModel.posts) { post in
                    Task { await viewModel.loadMorePostsIfNeeded(current: post) }
                }
            }
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
            EmptyStateView(icon: "bookmark", title: "No saved shops yet")
        } else {
            List {
                ForEach(viewModel.shops) { shop in
                    NavigationLink(value: AppRoute.shop(shop.id)) {
                        HStack(spacing: BumpSpacing.s) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(shop.name)
                                    .font(.subheadline.weight(.medium))
                                Text(shop.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            RatingStarsView(rating: shop.rate.value, size: 11)
                        }
                    }
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
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .listStyle(.plain)
            .refreshable { await viewModel.refresh() }
        }
    }
}
