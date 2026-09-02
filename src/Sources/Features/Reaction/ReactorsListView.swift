import SwiftUI

struct ReactorsListView: View {
    let kind: ReactorsKind
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ReactorsListViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.reactors.isEmpty {
                    LoadingView()
                } else if let errorMessage = viewModel.errorMessage, viewModel.reactors.isEmpty {
                    ErrorStateView(message: errorMessage) { Task { await viewModel.loadInitialIfNeeded() } }
                } else if viewModel.reactors.isEmpty {
                    EmptyStateView(icon: "heart", title: String(localized: "No reactions yet"))
                } else {
                    List {
                        ForEach(viewModel.reactors) { reactor in
                            NavigationLink(value: AppRoute.account(reactor.accountId)) {
                                HStack(spacing: BumpSpacing.s) {
                                    AvatarView(url: reactor.avatar?.url, size: 40)
                                    Text(reactor.name.value)
                                        .font(.subheadline.weight(.medium))
                                }
                            }
                            .task { await viewModel.loadMoreIfNeeded(current: reactor) }
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
                viewModel = ReactorsListViewModel(kind: kind, reactionService: environment.reactionService)
            }
            await viewModel?.loadInitialIfNeeded()
        }
        .navigationTitle("Reactions")
        .navigationBarTitleDisplayMode(.inline)
    }
}
