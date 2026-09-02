import SwiftUI

struct NotificationsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: NotificationsViewModel?
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
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
                EmptyStateView(icon: "bell", title: String(localized: "No notifications yet"), message: String(localized: "Likes, comments, and new followers show up here."))
            } else {
                List {
                    ForEach(viewModel.notifications) { notification in
                        rowContent(for: notification)
                            .task { await viewModel.loadMoreIfNeeded(current: notification) }
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
        }
    }

    @ViewBuilder
    private func rowContent(for notification: NotificationSummaryDto) -> some View {
        if let route = notification.route {
            NavigationLink(value: route) {
                NotificationRow(notification: notification)
            }
        } else {
            NotificationRow(notification: notification)
        }
    }
}

private struct NotificationRow: View {
    let notification: NotificationSummaryDto

    var body: some View {
        HStack(alignment: .top, spacing: BumpSpacing.s) {
            AvatarView(url: notification.actorAvatar?.url, size: 40)

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
        }
        .padding(.vertical, BumpSpacing.xs)
    }
}
