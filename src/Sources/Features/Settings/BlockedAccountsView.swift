import SwiftUI

/// The list of accounts the signed-in user has blocked, and the one place to lift a
/// block. Reads `GET /Block/me`, which returns only accounts *you* blocked — there is
/// deliberately no way to see who blocked you.
struct BlockedAccountsView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var blocked: [BlockDto] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var nextCursor: String?
    @State private var hasMore = true
    /// Ids unblocked in this session. The write is queued, so a reload can still hand
    /// back a row that is on its way out; this keeps it off the screen either way.
    @State private var lifted: Set<UUID> = []

    private var visible: [BlockDto] { blocked.filter { !lifted.contains($0.accountId) } }

    var body: some View {
        Group {
            if isLoading && blocked.isEmpty {
                LoadingView()
            } else if let errorMessage, blocked.isEmpty {
                ErrorStateView(message: errorMessage) { Task { await load(cursor: nil) } }
            } else if visible.isEmpty {
                EmptyStateView(
                    icon: "hand.raised",
                    title: String(localized: "No blocked accounts"),
                    message: String(localized: "Accounts you block are hidden from your feed, search, and comments. They show up here so you can undo it.")
                )
            } else {
                List {
                    ForEach(visible) { block in
                        BlockedAccountRow(block: block) {
                            Task { await unblock(block) }
                        }
                        .listRowBackground(BumpColor.surface)
                        .task { await loadMoreIfNeeded(current: block) }
                    }
                    if isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .listRowBackground(BumpColor.surface)
                    }
                }
                .listStyle(.plain)
                .bumpScrollBackground()
                .refreshable { await load(cursor: nil) }
            }
        }
        .navigationTitle("Blocked Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard blocked.isEmpty else { return }
            await load(cursor: nil)
        }
    }

    private func load(cursor: String?) async {
        if cursor == nil { isLoading = true } else { isLoadingMore = true }
        errorMessage = nil
        defer {
            if cursor == nil { isLoading = false } else { isLoadingMore = false }
        }
        do {
            let page = try await environment.blockService.mine(cursor: cursor)
            if cursor == nil {
                blocked = page.items
                lifted = []
            } else {
                blocked.append(contentsOf: page.items)
            }
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
            if cursor == nil { errorMessage = APIError.userMessage(for: error) }
        }
    }

    private func loadMoreIfNeeded(current: BlockDto) async {
        guard hasMore, !isLoadingMore, blocked.last?.accountId == current.accountId else { return }
        await load(cursor: nextCursor)
    }

    private func unblock(_ block: BlockDto) async {
        lifted.insert(block.accountId)
        let didUnblock = await environment.blockStore.unblock(block.accountId)
        if didUnblock {
            environment.feedRefreshSignal.bump()
        } else {
            lifted.remove(block.accountId)
            errorMessage = String(localized: "Couldn't unblock that account.")
        }
    }
}

private struct BlockedAccountRow: View {
    let block: BlockDto
    let onUnblock: () -> Void

    var body: some View {
        HStack(spacing: BumpSpacing.ms) {
            AvatarView(url: block.avatar?.url, size: 40)

            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                Text(block.name.value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BumpColor.textPrimary)
                    .lineLimit(1)
                Text("Blocked \(block.blockedAt.relativeDescription)")
                    .font(.caption)
                    .foregroundStyle(BumpColor.textSecondary)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: BumpSpacing.s)

            Button("Unblock", action: onUnblock)
                .buttonStyle(.bumpSecondary(isProminent: true))
                .fixedSize(horizontal: true, vertical: false)
                // Without this the button announces as a bare "Unblock", identical on
                // every row, with no way to tell which account it lifts.
                .accessibilityLabel(String(localized: "Unblock \(block.name.value)"))
        }
        .padding(.vertical, BumpSpacing.xs)
    }
}
