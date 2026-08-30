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
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, BumpSpacing.m)
            .padding(.top, BumpSpacing.s)

            if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyStateView(icon: "magnifyingglass", title: "Search Bump", message: "Find shops, posts, or people.")
            } else if viewModel.isLoading && isCurrentScopeEmpty {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage, isCurrentScopeEmpty {
                ErrorStateView(message: errorMessage) { Task { await viewModel.runSearch() } }
            } else {
                results
            }
        }
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
                EmptyStateView(icon: "photo", title: "No posts found")
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
                EmptyStateView(icon: "storefront", title: "No shops found")
            } else {
                List(viewModel.shops) { shop in
                    NavigationLink(value: AppRoute.shop(shop.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shop.name).font(.subheadline.weight(.semibold))
                            Text(shop.address).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .task { await viewModel.loadMoreShopsIfNeeded(current: shop) }
                }
                .listStyle(.plain)
            }
        case .accounts:
            if viewModel.accounts.isEmpty {
                EmptyStateView(icon: "person.2", title: "No people found")
            } else {
                List(viewModel.accounts) { account in
                    NavigationLink(value: AppRoute.account(account.id)) {
                        HStack(spacing: BumpSpacing.s) {
                            AvatarView(url: account.avatar?.url, size: 40)
                            Text(account.name.value).font(.subheadline.weight(.medium))
                        }
                    }
                    .task { await viewModel.loadMoreAccountsIfNeeded(current: account) }
                }
                .listStyle(.plain)
            }
        }
    }
}
