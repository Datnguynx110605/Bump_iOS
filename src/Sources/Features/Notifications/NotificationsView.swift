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
                        .autoRefresh(every: .seconds(60)) { await viewModel.refreshIfStale() }
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
                            .listRowBackground(BumpColor.surface)
                            .task { await viewModel.loadMoreIfNeeded(current: notification) }
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
        HStack(alignment: .top, spacing: BumpSpacing.ms) {
            AvatarView(url: notification.actorAvatar?.url, size: 40)
                .overlay(alignment: .bottomTrailing) {
                    if let badge {
                        Image(systemName: badge.symbol)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(badge.tint, in: Circle())
                            .overlay(Circle().strokeBorder(BumpColor.surface, lineWidth: 2))
                            .offset(x: 3, y: 3)
                    }
                }

            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                Text(notification.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BumpColor.textPrimary)
                Text(notification.content)
                    .font(.subheadline)
                    .foregroundStyle(BumpColor.textSecondary)
                Text(notification.createdAt.relativeDescription)
                    .font(.caption)
                    .foregroundStyle(BumpColor.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, BumpSpacing.s)
        .accessibilityElement(children: .combine)
    }

    /// Small glyph on the actor's avatar saying *why* this arrived, so the list is
    /// scannable without reading every line.
    private var badge: (symbol: String, tint: Color)? {
        switch notification.type {
        case .follow: return ("person.fill", BumpColor.brandFill)
        case .postReaction, .commentReaction: return ("heart.fill", BumpColor.like)
        case .comment: return ("bubble.right.fill", BumpColor.success)
        case nil: return nil
        }
    }
}
