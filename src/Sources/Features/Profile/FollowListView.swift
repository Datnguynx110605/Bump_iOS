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
                    LoadingView()
                } else if let errorMessage = viewModel.errorMessage, viewModel.rows.isEmpty {
                    ErrorStateView(message: errorMessage) { Task { await viewModel.loadInitialIfNeeded() } }
                } else if viewModel.rows.isEmpty {
                    EmptyStateView(icon: "person.2", title: String(localized: "No \(kind.displayNameLowercased) yet"))
                } else {
                    List {
                        ForEach(viewModel.rows) { row in
                            NavigationLink(value: AppRoute.account(row.id)) {
                                HStack(spacing: BumpSpacing.s) {
                                    AvatarView(url: row.avatarURL, size: 40)
                                    Text(row.name)
                                        .font(.subheadline.weight(.medium))
                                }
                            }
                            .task { await viewModel.loadMoreIfNeeded(current: row) }
                        }
                        if viewModel.isLoadingMore {
                            ProgressView().frame(maxWidth: .infinity)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(BumpColor.surface)
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
