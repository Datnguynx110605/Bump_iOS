import SwiftUI

struct FollowListView: View {
    let accountId: UUID
    let kind: FollowListKind
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: FollowListViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.rows.isEmpty {
                    PeopleSkeletonList()
                } else if let errorMessage = viewModel.errorMessage, viewModel.rows.isEmpty {
                    ErrorStateView(message: errorMessage) { Task { await viewModel.loadInitialIfNeeded() } }
                } else if viewModel.rows.isEmpty {
                    EmptyStateView(
                        glyph: .people,
                        title: "No \(kind.displayNameLowercased) yet"
                    )
                } else {
                    List {
                        ForEach(viewModel.rows) { row in
                            NavigationLink(value: AppRoute.account(row.id)) {
                                HStack(spacing: BumpSpacing.ms) {
                                    AvatarView(url: row.avatarURL, size: 44)
                                    Text(row.name)
                                        .font(BumpFont.subheadline)
                                        .foregroundStyle(BumpColor.textPrimary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, BumpSpacing.s)
                                .accessibilityElement(children: .combine)
                            }
                            .listRowBackground(BumpColor.surface)
                            .listRowSeparatorTint(BumpColor.hairline)
                            .task { await viewModel.loadMoreIfNeeded(current: row) }
                        }
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .tint(BumpColor.brand)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BumpSpacing.m)
                                .listRowBackground(BumpColor.surface)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .bumpScrollBackground()
                    .refreshable { await viewModel.reload() }
                }
            } else {
                LoadingView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = FollowListViewModel(accountId: accountId, kind: kind, followService: environment.followService)
            }
            await viewModel?.loadInitialIfNeeded()
        }
        .navigationTitle(kind.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
