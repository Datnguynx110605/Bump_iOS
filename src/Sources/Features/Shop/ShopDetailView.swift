import SwiftUI

struct ShopDetailView: View {
    let shopId: UUID
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ShopDetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                // Without this a failed shop lookup rendered a header-less page whose only
                // content was "No posts yet. Be the first to review this place." — a claim
                // about the shop, made on the strength of a request that never landed.
                if viewModel.shop == nil, let errorMessage = viewModel.errorMessage {
                    ErrorStateView(message: errorMessage) { Task { await viewModel.refresh() } }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: BumpSpacing.m) {
                            if let shop = viewModel.shop {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                                        Text(shop.name)
                                            .font(BumpFont.title)
                                            .foregroundStyle(BumpColor.textPrimary)
                                        Text(shop.address)
                                            .font(BumpFont.callout)
                                            .foregroundStyle(BumpColor.textSecondary)
                                        RatingStarsView(rating: shop.rate.value, size: BumpIconSize.small)
                                            .padding(.top, BumpSpacing.xs)
                                        Button {
                                            AppleMaps.openDirections(placeId: shop.placeId, shopName: shop.name, address: shop.address)
                                        } label: {
                                            Label("Get directions", systemImage: "arrow.triangle.turn.up.right.circle")
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

                            BumpDivider()

                            if viewModel.posts.isEmpty && !viewModel.isLoadingPosts {
                                EmptyStateView(
                                    icon: "camera",
                                    title: "Nobody's posted here yet",
                                    message: "Be the first to say what this place is like."
                                )
                                .frame(height: 260)
                            } else {
                                VStack(alignment: .leading, spacing: BumpSpacing.ms) {
                                    BumpSectionHeader("What people posted")
                                    PostThumbnailGrid(posts: viewModel.posts) { post in
                                        Task { await viewModel.loadMorePostsIfNeeded(current: post) }
                                    }
                                }
                            }
                        }
                        .padding(.top, BumpSpacing.m)
                    }
                    .bumpPage()
                    .refreshable { await viewModel.refresh() }
                }
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
