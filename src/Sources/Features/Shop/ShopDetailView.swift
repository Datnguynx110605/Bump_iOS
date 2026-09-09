import SwiftUI

struct ShopDetailView: View {
    let shopId: UUID
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ShopDetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                ScrollView {
                    VStack(alignment: .leading, spacing: BumpSpacing.m) {
                        if let shop = viewModel.shop {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                                    Text(shop.name)
                                        .font(.title.bold())
                                        .foregroundStyle(BumpColor.textPrimary)
                                    Text(shop.address)
                                        .font(.subheadline)
                                        .foregroundStyle(BumpColor.textSecondary)
                                    RatingStarsView(rating: shop.rate.value, size: BumpIconSize.small)
                                        .padding(.top, BumpSpacing.xs)
                                    Button {
                                        AppleMaps.openDirections(shopName: shop.name, address: shop.address)
                                    } label: {
                                        Label("View in Map", systemImage: "map")
                                    }
                                    .buttonStyle(.bumpText)
                                }
                                Spacer()
                                BumpToggleIconButton(
                                    isOn: viewModel.isSaved,
                                    onImage: "bookmark.fill",
                                    offImage: "bookmark",
                                    label: viewModel.isSaved ? String(localized: "Remove from saved") : String(localized: "Save shop")
                                ) {
                                    Task { viewModel.isSaved = await environment.saveStore.toggleShop(shopId) }
                                }
                            }
                            .padding(.horizontal, BumpSpacing.m)
                        } else if viewModel.isLoadingShop {
                            LoadingView().frame(height: 100)
                        }

                        Divider()

                        if viewModel.posts.isEmpty && !viewModel.isLoadingPosts {
                            EmptyStateView(
                                icon: "camera.fill",
                                title: String(localized: "No posts yet"),
                                message: String(localized: "Be the first to review this place.")
                            )
                            .frame(height: 220)
                        } else {
                            PostThumbnailGrid(posts: viewModel.posts) { post in
                                Task { await viewModel.loadMorePostsIfNeeded(current: post) }
                            }
                        }
                    }
                    .padding(.top, BumpSpacing.m)
                }
                .background(BumpColor.surface)
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
