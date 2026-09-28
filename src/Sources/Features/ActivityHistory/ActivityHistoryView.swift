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
                        glyph: .comments,
                        title: "Nothing here yet",
                        message: "Every comment you leave on a post is kept here."
                    )
                } else {
                    List {
                        ForEach(viewModel.comments) { comment in
                            CommentRowView(
                                comment: comment,
                                onDelete: { Task { await viewModel.deleteComment(comment) } },
                                onEdited: { viewModel.updateComment(comment, content: $0) }
                            )
                            .listRowBackground(BumpColor.surface)
                            .listRowSeparatorTint(BumpColor.hairline)
                            .task { await viewModel.loadMoreIfNeeded(current: comment) }
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
                viewModel = ActivityHistoryViewModel(commentService: environment.commentService)
            }
            await viewModel?.loadInitialIfNeeded()
        }
        .navigationTitle("Activity history")
        .navigationBarTitleDisplayMode(.inline)
    }
}
