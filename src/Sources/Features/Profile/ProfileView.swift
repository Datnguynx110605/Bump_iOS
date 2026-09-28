import SwiftUI

struct ProfileView: View {
    let accountId: UUID
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: ProfileViewModel?
    @State private var showingSettings = false
    @State private var showingReportSheet = false
    @State private var showingBlockConfirm = false
    @Environment(\.dismiss) private var dismiss

    private var isOwnProfile: Bool { accountId == authSession.accountId }

    var body: some View {
        Group {
            if let viewModel {
                // A failed account load used to leave the redacted placeholder header in
                // place above "No posts yet" — which tells the viewer this account has
                // nothing to show when in fact the request failed. Same distinction
                // `HomeViewModel.NearbyState` draws between `.failed` and an empty result.
                if viewModel.account == nil, let errorMessage = viewModel.errorMessage {
                    ErrorStateView(message: errorMessage) { Task { await viewModel.refresh() } }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: BumpSpacing.l) {
                            ProfileHeaderView(
                                viewModel: viewModel,
                                isOwnProfile: isOwnProfile,
                                onEditProfile: { showingSettings = true }
                            )

                            if viewModel.posts.isEmpty && !viewModel.isLoadingPosts {
                                EmptyStateView(
                                    glyph: .camera,
                                    title: isOwnProfile ? "Share your first spot" : "Nothing posted yet",
                                    message: isOwnProfile ? "Rate a place you love and it lands right here." : nil
                                )
                                .frame(height: 260)
                            } else {
                                VStack(alignment: .leading, spacing: BumpSpacing.ms) {
                                    BumpSectionHeader("Posts")
                                    // The grid bleeds to both screen edges; only the label
                                    // above it sits in the text gutter.
                                    PostThumbnailGrid(posts: viewModel.posts) { post in
                                        Task { await viewModel.loadMorePostsIfNeeded(current: post) }
                                    }
                                }
                            }
                        }
                        .padding(.top, BumpSpacing.m)
                    }
                    .background(BumpColor.surface)
                    .refreshable { await viewModel.refresh() }
                }
            } else {
                LoadingView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ProfileViewModel(
                    accountId: accountId,
                    accountService: environment.accountService,
                    postService: environment.postService
                )
            }
            await viewModel?.loadIfNeeded()
        }
        .onChange(of: environment.feedRefreshSignal.version) { _, _ in
            guard isOwnProfile else { return }
            Task { await viewModel?.refresh() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isOwnProfile {
                    HStack(spacing: BumpSpacing.s) {
                        NavigationLink(value: AppRoute.saved) {
                            BumpBarIcon(.bookmark)
                        }
                        .accessibilityLabel(String(localized: "Saved"))
                        Button { showingSettings = true } label: {
                            BumpBarIcon(.gear)
                        }
                        .accessibilityLabel(String(localized: "Settings"))
                    }
                } else {
                    Menu {
                        BumpMenuButton(title: "Report account", glyph: .flag) { showingReportSheet = true }
                        if environment.blockStore.isBlocked(accountId) {
                            BumpMenuButton(title: "Unblock account", glyph: .handRaised, variant: .slashed) {
                                Task {
                                    await environment.blockStore.unblock(accountId)
                                    environment.feedRefreshSignal.bump()
                                }
                            }
                        } else {
                            BumpMenuButton(title: "Block account", glyph: .handRaised, role: .destructive) {
                                showingBlockConfirm = true
                            }
                        }
                    } label: {
                        BumpBarIcon(.ellipsis, .circled)
                    }
                    .accessibilityLabel(String(localized: "More actions"))
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportSheet(target: .account(accountId))
        }
        .confirmationDialog(
            "Block this account? You won't see their posts or comments, and they won't see yours.",
            isPresented: $showingBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                Task {
                    await environment.blockStore.block(accountId)
                    environment.feedRefreshSignal.bump()
                    // This profile answers 404 for a blocked account, so staying here would
                    // replace it with an error screen the moment anything reloads.
                    dismiss()
                }
            }
        }
    }
}

/// The profile header, set left-aligned rather than centred.
///
/// A centred avatar/name/stats column is the default every social app ships; running the
/// same information down the left margin makes the screen read as a *page about a person*
/// — the name behaves like a headline, the stats like a standfirst under it.
///
/// **It reflows at accessibility text sizes.** The side-by-side arrangement puts a 76pt
/// avatar, a title-weight name and two stat pairs on one row, and at
/// `accessibility-extra-large` that row has nowhere left to go: verified on device, the
/// name jumped above the avatar and "Followers" hyphenated across three lines as
/// "Fol-low-ers". Past `isAccessibilitySize` the whole header stacks vertically instead,
/// where every element has the full width of the screen.
private struct ProfileHeaderView: View {
    @Bindable var viewModel: ProfileViewModel
    let isOwnProfile: Bool
    let onEditProfile: () -> Void
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isTogglingFollow = false

    /// Read straight off the `@Observable` store rather than copied into `@State`.
    /// `FollowStore.primeIfNeeded()` runs concurrently from `RootView` at sign-in, so a
    /// profile opened before priming finished used to show "Follow" for someone already
    /// followed and never correct itself. The store already applies the optimistic
    /// toggle and its rollback, so there is nothing a local copy adds.
    private var isFollowing: Bool { environment.followStore.isFollowing(viewModel.accountId) }

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.m) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: BumpSpacing.m) {
                    AvatarView(url: viewModel.account?.avatar?.url, size: 76)
                    nameText
                    VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                        followersLink
                        followingLink
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: BumpSpacing.m) {
                    AvatarView(url: viewModel.account?.avatar?.url, size: 76)

                    VStack(alignment: .leading, spacing: BumpSpacing.s) {
                        nameText
                        HStack(spacing: BumpSpacing.m) {
                            followersLink
                            followingLink
                        }
                    }

                    Spacer(minLength: 0)
                }
            }

            if let bio = viewModel.account?.bio, !bio.isEmpty {
                Text(bio)
                    .font(BumpFont.callout)
                    .foregroundStyle(BumpColor.textSecondary)
                    .lineSpacing(BumpLeading.prose)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isOwnProfile {
                Button("Edit profile", action: onEditProfile)
                    .buttonStyle(.bumpSecondary)
            } else {
                Button {
                    Task { await toggleFollow() }
                } label: {
                    Text(isFollowing ? "Following" : "Follow")
                }
                .buttonStyle(.bumpSecondary(isProminent: !isFollowing))
                .disabled(isTogglingFollow)
                .accessibilityAddTraits(isFollowing ? [.isSelected] : [])
                .bumpAnimation(BumpMotion.standard, value: isFollowing)
            }
        }
        .padding(.horizontal, BumpSpacing.m)
    }

    private var nameText: some View {
        Text(viewModel.account?.name.value ?? "            ")
            .font(BumpFont.title)
            .foregroundStyle(BumpColor.textPrimary)
            .lineLimit(2)
            .redacted(reason: viewModel.account == nil ? .placeholder : [])
    }

    /// Follower and following counts set inline as prose rather than as two boxed tiles
    /// with a rule between them — the tiles were small containers, and this system
    /// doesn't draw containers around text.
    private var followersLink: some View {
        NavigationLink(value: AppRoute.followers(viewModel.accountId)) {
            stat(count: viewModel.account?.followerAmount.value, label: String(localized: "Followers"))
        }
        .buttonStyle(.bumpSurface)
    }

    private var followingLink: some View {
        NavigationLink(value: AppRoute.following(viewModel.accountId)) {
            stat(count: viewModel.account?.followingAmount.value, label: String(localized: "Following"))
        }
        .buttonStyle(.bumpSurface)
    }

    private func toggleFollow() async {
        isTogglingFollow = true
        defer { isTogglingFollow = false }
        let wasFollowing = isFollowing
        let nowFollowing = await environment.followStore.toggle(viewModel.accountId)
        if nowFollowing && !wasFollowing {
            HapticFeedback.reacted()
        }
    }

    private func stat(count: Int?, label: String) -> some View {
        HStack(spacing: BumpSpacing.xs) {
            Text(count.map(String.init) ?? "–")
                .font(BumpFont.numeric)
                .foregroundStyle(BumpColor.textPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(BumpFont.meta)
                .foregroundStyle(BumpColor.textSecondary)
                // Never hyphenate a one-word label. Without this the squeezed row broke
                // "Followers" into "Fol-low-ers" rather than letting the row grow.
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minHeight: BumpHitTarget.min)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
