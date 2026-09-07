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
                    EmptyStateView(icon: "heart.fill", title: String(localized: "No reactions yet"))
                } else {
                    List {
                        ForEach(viewModel.reactors) { reactor in
                            NavigationLink(value: AppRoute.account(reactor.accountId)) {
                                HStack(spacing: BumpSpacing.ms) {
                                    AvatarView(url: reactor.avatar?.url, size: 40)
                                    Text(reactor.name.value)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(BumpColor.textPrimary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, BumpSpacing.xs)
                                .accessibilityElement(children: .combine)
                            }
                            .listRowBackground(BumpColor.surface)
                            .task { await viewModel.loadMoreIfNeeded(current: reactor) }
                        }
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .listRowBackground(BumpColor.surface)
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
