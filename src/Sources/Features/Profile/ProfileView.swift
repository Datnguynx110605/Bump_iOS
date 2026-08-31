import SwiftUI

struct ProfileView: View {
    let accountId: UUID
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: ProfileViewModel?
    @State private var showingSettings = false
    @State private var showingReportSheet = false

    private var isOwnProfile: Bool { accountId == authSession.accountId }

    var body: some View {
        Group {
            if let viewModel {
                ScrollView {
                    VStack(spacing: BumpSpacing.m) {
                        ProfileHeaderView(
                            viewModel: viewModel,
                            isOwnProfile: isOwnProfile,
                            onEditProfile: { showingSettings = true }
                        )

                        Divider()

                        if viewModel.posts.isEmpty && !viewModel.isLoadingPosts {
                            EmptyStateView(
                                icon: "photo.on.rectangle.angled",
                                title: isOwnProfile ? String(localized: "Share your first post") : String(localized: "No posts yet")
                            )
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
                    HStack(spacing: BumpSpacing.m) {
                        NavigationLink(value: AppRoute.saved) {
                            Image(systemName: "bookmark")
                        }
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                } else {
                    Menu {
                        Button("Report Account", systemImage: "flag") { showingReportSheet = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportSheet(target: .account(accountId))
        }
    }
}

private struct ProfileHeaderView: View {
    @Bindable var viewModel: ProfileViewModel
    let isOwnProfile: Bool
    let onEditProfile: () -> Void
    @Environment(AppEnvironment.self) private var environment
    @State private var isFollowing = false

    var body: some View {
        VStack(spacing: BumpSpacing.m) {
            AvatarView(url: viewModel.account?.avatar?.url, size: 88)

            VStack(spacing: 2) {
                Text(viewModel.account?.name.value ?? "…")
                    .font(.title2.bold())
                    .redacted(reason: viewModel.account == nil ? .placeholder : [])
                if let bio = viewModel.account?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BumpSpacing.l)
                }
            }

            HStack(spacing: BumpSpacing.xl) {
                NavigationLink(value: AppRoute.followers(viewModel.accountId)) {
                    statTile(count: viewModel.account?.followerAmount.value, label: String(localized: "Followers"))
                }
                .buttonStyle(.plain)
                NavigationLink(value: AppRoute.following(viewModel.accountId)) {
                    statTile(count: viewModel.account?.followingAmount.value, label: String(localized: "Following"))
                }
                .buttonStyle(.plain)
            }

            if isOwnProfile {
                Button("Edit Profile", action: onEditProfile)
                    .buttonStyle(.bordered)
            } else if isFollowing {
                Button {
                    Task { isFollowing = await environment.followStore.toggle(viewModel.accountId) }
                } label: {
                    Text("Following").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, BumpSpacing.xl)
            } else {
                Button {
                    Task { isFollowing = await environment.followStore.toggle(viewModel.accountId) }
                } label: {
                    Text("Follow").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, BumpSpacing.xl)
            }
        }
        .task { isFollowing = environment.followStore.isFollowing(viewModel.accountId) }
    }

    private func statTile(count: Int?, label: String) -> some View {
        VStack(spacing: 2) {
            Text(count.map(String.init) ?? "–")
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
