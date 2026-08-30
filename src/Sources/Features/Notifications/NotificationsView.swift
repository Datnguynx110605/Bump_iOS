import SwiftUI

struct NotificationsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: NotificationsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    NotificationsListView(viewModel: viewModel)
                } else {
                    LoadingView()
                }
            }
            .navigationTitle("Notifications")
            .appRouteDestinations()
        }
        .task {
            if viewModel == nil {
                let newViewModel = NotificationsViewModel(notificationService: environment.notificationService)
                environment.notificationHubClient.onNotification = { [weak newViewModel] notification in
                    newViewModel?.prepend(notification)
                }
                viewModel = newViewModel
            }
            await viewModel?.loadInitialIfNeeded()
        }
    }
}

private struct NotificationsListView: View {
    @Bindable var viewModel: NotificationsViewModel

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.notifications.isEmpty {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage, viewModel.notifications.isEmpty {
                ErrorStateView(message: errorMessage) { Task { await viewModel.reload() } }
            } else if viewModel.notifications.isEmpty {
                EmptyStateView(icon: "bell", title: "No notifications yet", message: "Likes, comments, and new followers show up here.")
            } else {
                List {
                    ForEach(viewModel.notifications) { notification in
                        VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                            Text(notification.title)
                                .font(.subheadline.weight(.semibold))
                            Text(notification.content)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(notification.createdAt.relativeDescription)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, BumpSpacing.xs)
                        .task { await viewModel.loadMoreIfNeeded(current: notification) }
                    }
                    if viewModel.isLoadingMore {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                .listStyle(.plain)
                .refreshable { await viewModel.reload() }
            }
        }
    }
}
