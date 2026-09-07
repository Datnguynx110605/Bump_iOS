import SwiftUI

struct ActivityHistoryView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ActivityHistoryViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.comments.isEmpty {
                    LoadingView()
                } else if let errorMessage = viewModel.errorMessage, viewModel.comments.isEmpty {
                    ErrorStateView(message: errorMessage) { Task { await viewModel.loadInitialIfNeeded() } }
                } else if viewModel.comments.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: String(localized: "No comments yet"),
                        message: String(localized: "Comments you leave on posts show up here.")
                    )
                } else {
                    List {
                        ForEach(viewModel.comments) { comment in
                            CommentRowView(comment: comment, onDelete: {
                                Task { await viewModel.deleteComment(comment) }
                            })
                            .listRowBackground(BumpColor.surface)
                            .task { await viewModel.loadMoreIfNeeded(current: comment) }
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
                viewModel = ActivityHistoryViewModel(commentService: environment.commentService)
            }
            await viewModel?.loadInitialIfNeeded()
        }
        .navigationTitle("Activity History")
        .navigationBarTitleDisplayMode(.inline)
    }
}
