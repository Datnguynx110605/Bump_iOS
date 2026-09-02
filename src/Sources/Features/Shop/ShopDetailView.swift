import SwiftUI

struct ShopDetailView: View {
    let shopId: UUID
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ShopDetailViewModel?
    @ScaledMetric private var bookmarkIconSize: CGFloat = BumpIconSize.medium

    var body: some View {
        Group {
            if let viewModel {
                ScrollView {
                    VStack(alignment: .leading, spacing: BumpSpacing.m) {
                        if let shop = viewModel.shop {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                                    Text(shop.name)
                                        .font(.largeTitle.bold())
                                    Text(shop.address)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    RatingStarsView(rating: shop.rate.value, size: 16)
                                        .padding(.top, 2)
                                    Button {
                                        AppleMaps.openDirections(shopName: shop.name, address: shop.address)
                                    } label: {
                                        Label("View in Map", systemImage: "map")
                                            .font(.footnote.weight(.medium))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 2)
                                }
                                Spacer()
                                Button {
                                    Task {
                                        let saved = await environment.saveStore.toggleShop(shopId)
                                        viewModel.isSaved = saved
                                    }
                                } label: {
                                    Image(systemName: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                                        .font(.system(size: bookmarkIconSize))
                                        .foregroundStyle(viewModel.isSaved ? Color.accentColor : BumpColor.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, BumpSpacing.m)
                        } else if viewModel.isLoadingShop {
                            LoadingView().frame(height: 100)
                        }

                        Divider()

                        if viewModel.posts.isEmpty && !viewModel.isLoadingPosts {
                            EmptyStateView(icon: "photo.on.rectangle.angled", title: String(localized: "No posts yet"))
                                .frame(height: 200)
                        } else {
                            PostThumbnailGrid(posts: viewModel.posts) { post in
                                Task { await viewModel.loadMorePostsIfNeeded(current: post) }
                            }
                        }
                    }
                    .padding(.top, BumpSpacing.m)
                }
                .refreshable { await viewModel.refresh() }
            } else {
                LoadingView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ShopDetailViewModel(shopId: shopId, shopService: environment.shopService, postService: environment.postService)
            }
            await viewModel?.loadIfNeeded()
            if let isSaved = viewModel?.isSaved {
                environment.saveStore.setSaved(shop: shopId, isSaved)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
