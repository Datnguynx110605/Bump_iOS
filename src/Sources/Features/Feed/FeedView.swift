import SwiftUI

struct FeedView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: FeedViewModel?
    @State private var hasAppearedOnce = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Bump")
                .appRouteDestinations()
        }
        .task {
            if viewModel == nil {
                viewModel = FeedViewModel(postService: environment.postService)
            }
            await viewModel?.loadInitialIfNeeded()
        }
        .onAppear {
            if hasAppearedOnce {
                Task { await viewModel?.reload() }
            }
            hasAppearedOnce = true
        }
        .onChange(of: environment.feedRefreshSignal.version) { _, _ in
            Task { await viewModel?.reload() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            FeedListView(viewModel: viewModel)
        } else {
            LoadingView()
        }
    }
}

private struct FeedListView: View {
    @Bindable var viewModel: FeedViewModel

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage, viewModel.posts.isEmpty {
                ErrorStateView(message: errorMessage) { Task { await viewModel.reload() } }
            } else {
                List {
                    Section {
                        Picker("Sort", selection: $viewModel.sort) {
                            ForEach(FeedSort.allCases) { sort in
                                Text(sort.rawValue).tag(sort)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }

                    if viewModel.posts.isEmpty {
                        EmptyStateView(
                            icon: "photo.on.rectangle.angled",
                            title: "No posts yet",
                            message: "Be the first to share a spot."
                        )
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(viewModel.posts) { item in
                            PostRowView(item: item)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                        }
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await viewModel.reload() }
            }
        }
    }
}
