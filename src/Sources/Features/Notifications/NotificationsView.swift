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
                VStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { _ in
                        HStack(alignment: .top, spacing: BumpSpacing.ms) {
                            Circle().fill(BumpColor.fill).frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: BumpSpacing.s) {
                                BumpSkeletonBlock(width: 140, height: 12)
                                BumpSkeletonBlock(height: 12)
                            }
                        }
                        .padding(.horizontal, BumpSpacing.m)
                        .padding(.vertical, BumpSpacing.ms)
                    }
                    Spacer()
                }
                .bumpPage()
            } else if let errorMessage = viewModel.errorMessage, viewModel.notifications.isEmpty {
                ErrorStateView(message: errorMessage) { Task { await viewModel.reload() } }
            } else if viewModel.notifications.isEmpty {
                EmptyStateView(icon: "bell", title: "All quiet", message: "Likes, comments and new followers will turn up here.")
            } else {
                List {
                    ForEach(viewModel.notifications) { notification in
                        rowContent(for: notification)
                            .listRowBackground(BumpColor.surface)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .task { await viewModel.loadMoreIfNeeded(current: notification) }

                        // The app draws its own warm hairline rather than `List`'s cool
                        // system separator, inset past the avatar so the column of faces
                        // reads as one rail.
                        BumpDivider(inset: BumpSpacing.m + 44 + BumpSpacing.ms)
                            .listRowBackground(BumpColor.surface)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
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
                // The hairline is its own row, and List floors every row at 44pt — which
                // is what put ~68pt between notifications instead of the 24pt the
                // skeleton above shows.
                .environment(\.defaultMinListRowHeight, 0)
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
            AvatarView(url: notification.actorAvatar?.url, size: 44)
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

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(BumpFont.subheadline)
                    .foregroundStyle(BumpColor.textPrimary)
                Text(notification.content)
                    .font(BumpFont.callout)
                    .foregroundStyle(BumpColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                // A timestamp is the only place this line appears, so it is content and
                // takes `textSecondary`. `textTertiary` is ~1.7:1 on a light page and this
                // file's own palette reserves it for glyphs that carry nothing.
                Text(notification.createdAt.relativeDescription)
                    .font(BumpFont.meta)
                    .foregroundStyle(BumpColor.textSecondary)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, BumpSpacing.m)
        .padding(.vertical, BumpSpacing.ms)
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
