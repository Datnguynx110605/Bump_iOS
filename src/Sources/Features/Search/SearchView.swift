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
    @Environment(AppEnvironment.self) private var environment

    /// Search pages are cached per keyword and the block is queued, so a just-blocked
    /// author can still come back in results. Same reason as the feed.
    private var visiblePosts: [PostFeedItemDto] {
        environment.blockStore.visible(viewModel.posts) { $0.post.accountId }
    }

    private var visibleAccounts: [AccountSummaryDto] {
        environment.blockStore.visible(viewModel.accounts) { $0.id }
    }

    /// True exactly when `shopDirectory` is what the screen is showing — which is
    /// whenever the field is empty, whatever scope is selected underneath.
    private var showsDirectory: Bool {
        viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // **Browse before search.** This screen used to open on a prompt — an icon
            // and "What are you after?" — with the shop directory hidden one chip away
            // under Shops. A discovery tab whose default state is a dead end is the
            // single worst thing a content app can do with its second tab, so the
            // directory is now the landing state and the prompt is gone.
            //
            // The scope chips come back the moment there is a query, because that is the
            // only moment they mean anything: with an empty field they described a filter
            // over nothing, while appearing to contradict the shop list below them.
            if showsDirectory {
                shopDirectory
            } else {
                scopeChips

                if viewModel.isLoading && isCurrentScopeEmpty {
                    loadingForCurrentScope
                } else if let errorMessage = viewModel.errorMessage, isCurrentScopeEmpty {
                    ErrorStateView(message: errorMessage) { viewModel.retrySearch() }
                } else {
                    results
                }
            }
        }
        .bumpPage()
        .task(id: showsDirectory) {
            guard showsDirectory else { return }
            await viewModel.loadDirectoryIfNeeded()
        }
    }

    /// Pill chips instead of a segmented control.
    ///
    /// A `.segmented` picker draws its own bordered, inset track — a small floating
    /// container, which is the one thing this design language doesn't do. Chips carry the
    /// same "pick one of three" meaning with nothing but a fill, and they scroll if a
    /// translation makes the three labels wider than the screen.
    private var scopeChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: BumpSpacing.s) {
                ForEach(SearchScope.allCases) { scope in
                    BumpChip(
                        title: scope.titleKey,
                        isSelected: viewModel.scope == scope
                    ) {
                        guard viewModel.scope != scope else { return }
                        HapticFeedback.selected()
                        viewModel.scope = scope
                    }
                }
            }
            .padding(.horizontal, BumpSpacing.m)
            .padding(.vertical, BumpSpacing.s)
        }
        .scrollIndicators(.hidden)
        // The chip row is a single set of alternatives, so VoiceOver should walk it as
        // one group of tabs rather than three unrelated buttons on the page.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Search in"))
    }

    /// Results wait in the shape they'll arrive in: post results are feed rows, shops and
    /// people are list rows.
    @ViewBuilder
    private var loadingForCurrentScope: some View {
        switch viewModel.scope {
        case .posts:
            ScrollView { BumpSkeletonList(count: 2) }.bumpPage()
        case .shops, .accounts:
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: BumpSpacing.ms) {
                        BumpSkeletonBlock(width: 44, height: 44, cornerRadius: BumpRadius.small)
                        BumpSkeletonBlock(width: 180, height: 12)
                        Spacer()
                    }
                    .padding(.horizontal, BumpSpacing.m)
                    .padding(.vertical, BumpSpacing.ms)
                }
                Spacer()
            }
            .bumpPage()
        }
    }

    @ViewBuilder
    private var shopDirectory: some View {
        if viewModel.directory.isEmpty {
            if viewModel.isLoadingDirectory {
                loadingForCurrentScope
            } else if let directoryError = viewModel.directoryError {
                // A failed lookup is not an empty directory, and saying "No shops yet"
                // here would tell the user something untrue about the app.
                ErrorStateView(message: directoryError) {
                    Task { await viewModel.retryDirectory() }
                }
            } else {
                EmptyStateView(
                    icon: "storefront",
                    title: "No shops yet",
                    message: "Shops show up here the moment someone posts about one. Be the first."
                )
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    BumpSectionHeader("Every shop on Bump")
                        .padding(.top, BumpSpacing.s)
                        .padding(.bottom, BumpSpacing.ms)

                    ForEach(viewModel.directory) { shop in
                        NavigationLink(value: AppRoute.shop(shop.id)) {
                            ShopResultRow(shop: shop)
                        }
                        .buttonStyle(.bumpSurface)
                        .task { await viewModel.loadMoreDirectoryIfNeeded(current: shop) }

                        BumpDivider(inset: Self.rowDividerInset)
                    }
                }
            }
            .bumpPage()
        }
    }

    /// Dividers start after the leading thumbnail rather than at the screen edge, so the
    /// column of icons reads as one continuous rail down the list.
    private static let rowDividerInset: CGFloat = BumpSpacing.m + 44 + BumpSpacing.ms

    private var isCurrentScopeEmpty: Bool {
        switch viewModel.scope {
        case .posts: return visiblePosts.isEmpty
        case .shops: return viewModel.shops.isEmpty
        case .accounts: return visibleAccounts.isEmpty
        }
    }

    @ViewBuilder
    private var results: some View {
        switch viewModel.scope {
        case .posts:
            if visiblePosts.isEmpty {
                EmptyStateView(
                    icon: "photo",
                    title: "No posts match that",
                    message: "Try a shorter word, or search shops instead."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visiblePosts) { item in
                            PostRowView(item: item)
                                .task { await viewModel.loadMorePostsIfNeeded(current: item) }
                        }
                    }
                }
                .bumpPage()
            }
        case .shops:
            if viewModel.shops.isEmpty {
                EmptyStateView(
                    icon: "storefront",
                    title: "No shops match that",
                    message: "Check the spelling, or try the name of the street."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.shops) { shop in
                            NavigationLink(value: AppRoute.shop(shop.id)) {
                                ShopResultRow(shop: shop)
                            }
                            .buttonStyle(.bumpSurface)
                            .task { await viewModel.loadMoreShopsIfNeeded(current: shop) }

                            BumpDivider(inset: Self.rowDividerInset)
                        }
                    }
                }
                .bumpPage()
            }
        case .accounts:
            if visibleAccounts.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "No one by that name",
                    message: "Usernames are lowercase and have no spaces."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleAccounts) { account in
                            NavigationLink(value: AppRoute.account(account.id)) {
                                AccountResultRow(account: account)
                            }
                            .buttonStyle(.bumpSurface)
                            .task { await viewModel.loadMoreAccountsIfNeeded(current: account) }

                            BumpDivider(inset: Self.rowDividerInset)
                        }
                    }
                }
                .bumpPage()
            }
        }
    }
}

/// A shop in a list. The leading tile is a tonal square with a light-weight glyph —
/// the same treatment as an avatar's placeholder, so shops and people sit on one rail
/// without either looking like the more important kind of result.
private struct ShopResultRow: View {
    let shop: ShopSummaryDto

    var body: some View {
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

            VStack(alignment: .leading, spacing: 2) {
                Text(shop.name)
                    .font(BumpFont.subheadline)
                    .foregroundStyle(BumpColor.textPrimary)
                    .lineLimit(1)
                Text(shop.address)
                    .font(BumpFont.meta)
                    .foregroundStyle(BumpColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: BumpSpacing.s)

            RatingStarsView(rating: shop.rate.value)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BumpColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, BumpSpacing.m)
        .padding(.vertical, BumpSpacing.ms)
        .accessibilityElement(children: .combine)
    }
}

private struct AccountResultRow: View {
    let account: AccountSummaryDto

    var body: some View {
        HStack(spacing: BumpSpacing.ms) {
            AvatarView(url: account.avatar?.url, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name.value)
                    .font(BumpFont.subheadline)
                    .foregroundStyle(BumpColor.textPrimary)
                    .lineLimit(1)
                if let bio = account.bio, !bio.isEmpty {
                    Text(bio)
                        .font(BumpFont.meta)
                        .foregroundStyle(BumpColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BumpColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, BumpSpacing.m)
        .padding(.vertical, BumpSpacing.ms)
        .accessibilityElement(children: .combine)
    }
}
