import SwiftUI

struct SearchView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: SearchViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    SearchResultsView(viewModel: viewModel)
                        .searchable(
                            text: Binding(get: { viewModel.query }, set: { viewModel.query = $0 }),
                            prompt: "Shops, posts, or people"
                        )
                } else {
                    LoadingView()
                }
            }
            .navigationTitle("Search")
            .appRouteDestinations()
        }
        .task {
            if viewModel == nil {
                viewModel = SearchViewModel(
                    postService: environment.postService,
                    shopService: environment.shopService,
                    accountService: environment.accountService
                )
            }
        }
    }
}

private struct SearchResultsView: View {
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("Scope", selection: $viewModel.scope) {
                ForEach(SearchScope.allCases) { scope in
                    Text(scope.displayName).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, BumpSpacing.m)
            .padding(.vertical, BumpSpacing.s)

            if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: String(localized: "Search Bump"),
                    message: String(localized: "Find shops, posts, or people.")
                )
            } else if viewModel.isLoading && isCurrentScopeEmpty {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage, isCurrentScopeEmpty {
                ErrorStateView(message: errorMessage) { Task { await viewModel.runSearch() } }
            } else {
                results
            }
        }
        .background(BumpColor.surface)
    }

    private var isCurrentScopeEmpty: Bool {
        switch viewModel.scope {
        case .posts: return viewModel.posts.isEmpty
        case .shops: return viewModel.shops.isEmpty
        case .accounts: return viewModel.accounts.isEmpty
        }
    }

    @ViewBuilder
    private var results: some View {
        switch viewModel.scope {
        case .posts:
            if viewModel.posts.isEmpty {
                EmptyStateView(icon: "photo", title: String(localized: "No posts found"))
            } else {
                ScrollView {
                    LazyVStack(spacing: BumpSpacing.m) {
                        ForEach(viewModel.posts) { item in
                            PostRowView(item: item)
                                .task { await viewModel.loadMorePostsIfNeeded(current: item) }
                        }
                    }
                    .padding(BumpSpacing.m)
                }
            }
        case .shops:
            if viewModel.shops.isEmpty {
                EmptyStateView(icon: "storefront", title: String(localized: "No shops found"))
            } else {
                List(viewModel.shops) { shop in
                    NavigationLink(value: AppRoute.shop(shop.id)) {
                        ShopResultRow(shop: shop)
                    }
                    .listRowBackground(BumpColor.surface)
                    .task { await viewModel.loadMoreShopsIfNeeded(current: shop) }
                }
                .listStyle(.plain)
                .bumpScrollBackground()
            }
        case .accounts:
            if viewModel.accounts.isEmpty {
                EmptyStateView(icon: "person.2", title: String(localized: "No people found"))
            } else {
                List(viewModel.accounts) { account in
                    NavigationLink(value: AppRoute.account(account.id)) {
                        AccountResultRow(account: account)
                    }
                    .listRowBackground(BumpColor.surface)
                    .task { await viewModel.loadMoreAccountsIfNeeded(current: account) }
                }
                .listStyle(.plain)
                .bumpScrollBackground()
            }
        }
    }
}

private struct ShopResultRow: View {
    let shop: ShopSummaryDto

    var body: some View {
        HStack(spacing: BumpSpacing.ms) {
            RoundedRectangle(cornerRadius: BumpRadius.small, style: .continuous)
                .fill(BumpColor.brand.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.footnote)
                        .foregroundStyle(BumpColor.brand)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
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
}

private struct AccountResultRow: View {
    let account: AccountSummaryDto

    var body: some View {
        HStack(spacing: BumpSpacing.ms) {
            AvatarView(url: account.avatar?.url, size: 40)
            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                Text(account.name.value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BumpColor.textPrimary)
                if let bio = account.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(BumpColor.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, BumpSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}
