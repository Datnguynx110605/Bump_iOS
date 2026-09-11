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
                ScrollView {
                    VStack(spacing: BumpSpacing.l) {
                        ProfileHeaderView(
                            viewModel: viewModel,
                            isOwnProfile: isOwnProfile,
                            onEditProfile: { showingSettings = true }
                        )

                        Divider()

                        if viewModel.posts.isEmpty && !viewModel.isLoadingPosts {
                            EmptyStateView(
                                icon: "camera.fill",
                                title: isOwnProfile ? String(localized: "Share your first post") : String(localized: "No posts yet"),
                                message: isOwnProfile ? String(localized: "Rate a coffee shop or restaurant and it shows up here.") : nil
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
                            Image(systemName: "bookmark")
                        }
                        .accessibilityLabel(String(localized: "Saved"))
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(String(localized: "Settings"))
                    }
                } else {
                    Menu {
                        Button("Report Account", systemImage: "flag") { showingReportSheet = true }
                        if environment.blockStore.isBlocked(accountId) {
                            Button("Unblock Account", systemImage: "hand.raised.slash") {
                                Task {
                                    await environment.blockStore.unblock(accountId)
                                    environment.feedRefreshSignal.bump()
                                }
                            }
                        } else {
                            Button("Block Account", systemImage: "hand.raised", role: .destructive) {
                                showingBlockConfirm = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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

private struct ProfileHeaderView: View {
    @Bindable var viewModel: ProfileViewModel
    let isOwnProfile: Bool
    let onEditProfile: () -> Void
    @Environment(AppEnvironment.self) private var environment
    @State private var isFollowing = false
    @State private var isTogglingFollow = false

    var body: some View {
        VStack(spacing: BumpSpacing.m) {
            AvatarView(url: viewModel.account?.avatar?.url, size: 88)

            VStack(spacing: BumpSpacing.xs) {
                Text(viewModel.account?.name.value ?? "            ")
                    .font(.title2.bold())
                    .foregroundStyle(BumpColor.textPrimary)
                    .redacted(reason: viewModel.account == nil ? .placeholder : [])
                if let bio = viewModel.account?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(BumpColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            HStack(spacing: 0) {
                NavigationLink(value: AppRoute.followers(viewModel.accountId)) {
                    statTile(count: viewModel.account?.followerAmount.value, label: String(localized: "Followers"))
                }
                .buttonStyle(.plain)

                Divider().frame(height: 28)

                NavigationLink(value: AppRoute.following(viewModel.accountId)) {
                    statTile(count: viewModel.account?.followingAmount.value, label: String(localized: "Following"))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 280)

            if isOwnProfile {
                Button("Edit Profile", action: onEditProfile)
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
            }
        }
        .padding(.horizontal, BumpSpacing.l)
        .task { isFollowing = environment.followStore.isFollowing(viewModel.accountId) }
    }

    private func toggleFollow() async {
        isTogglingFollow = true
        defer { isTogglingFollow = false }
        let nowFollowing = await environment.followStore.toggle(viewModel.accountId)
        if nowFollowing && !isFollowing {
            HapticFeedback.reacted()
        }
        isFollowing = nowFollowing
    }

    private func statTile(count: Int?, label: String) -> some View {
        VStack(spacing: BumpSpacing.xs) {
            Text(count.map(String.init) ?? "–")
                .font(.title3.weight(.bold))
                .foregroundStyle(BumpColor.textPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(BumpColor.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: BumpHitTarget.min)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
