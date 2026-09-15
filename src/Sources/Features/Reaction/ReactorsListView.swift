import SwiftUI

struct ReactorsListView: View {
    let kind: ReactorsKind
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ReactorsListViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.reactors.isEmpty {
                    PeopleSkeletonList()
                } else if let errorMessage = viewModel.errorMessage, viewModel.reactors.isEmpty {
                    ErrorStateView(message: errorMessage) { Task { await viewModel.loadInitialIfNeeded() } }
                } else if viewModel.reactors.isEmpty {
                    EmptyStateView(
                        icon: "heart",
                        title: "No likes yet",
                        message: "The first one always shows up eventually."
                    )
                } else {
                    List {
                        ForEach(viewModel.reactors) { reactor in
                            NavigationLink(value: AppRoute.account(reactor.accountId)) {
                                HStack(spacing: BumpSpacing.ms) {
                                    AvatarView(url: reactor.avatar?.url, size: 44)
                                    Text(reactor.name.value)
                                        .font(BumpFont.subheadline)
                                        .foregroundStyle(BumpColor.textPrimary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, BumpSpacing.s)
                                .accessibilityElement(children: .combine)
                            }
                            .listRowBackground(BumpColor.surface)
                            .listRowSeparatorTint(BumpColor.hairline)
                            .task { await viewModel.loadMoreIfNeeded(current: reactor) }
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
                viewModel = ReactorsListViewModel(kind: kind, reactionService: environment.reactionService)
            }
            await viewModel?.loadInitialIfNeeded()
        }
        .navigationTitle("Reactions")
        .navigationBarTitleDisplayMode(.inline)
    }
}
