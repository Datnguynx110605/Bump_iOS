import Foundation

enum FollowListKind: String {
    case followers = "Followers"
    case following = "Following"

    var displayName: String {
        switch self {
        case .followers: String(localized: "Followers")
        case .following: String(localized: "Following")
        }
    }

    var displayNameLowercased: String {
        switch self {
        case .followers: String(localized: "followers")
        case .following: String(localized: "following")
        }
    }
}

struct FollowListRow: Identifiable {
    let id: UUID
    let name: String
    let avatarURL: String?
}

@MainActor
@Observable
final class FollowListViewModel {
    let accountId: UUID
    let kind: FollowListKind

    var rows: [FollowListRow] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    private var nextCursor: String?
    private var hasMore = true
    private let followService: FollowService

    init(accountId: UUID, kind: FollowListKind, followService: FollowService) {
        self.accountId = accountId
        self.kind = kind
        self.followService = followService
    }

    func loadInitialIfNeeded() async {
        guard rows.isEmpty else { return }
        await load(cursor: nil, append: false)
    }

    func reload() async {
        await load(cursor: nil, append: false)
    }

    func loadMoreIfNeeded(current: FollowListRow) async {
        guard hasMore, !isLoadingMore, rows.last?.id == current.id else { return }
        await load(cursor: nextCursor, append: true)
    }

    private func load(cursor: String?, append: Bool) async {
        if append { isLoadingMore = true } else { isLoading = true }
        errorMessage = nil
        defer {
            if append { isLoadingMore = false } else { isLoading = false }
        }
        do {
            switch kind {
            case .followers:
                let page = try await followService.followers(of: accountId, cursor: cursor)
                apply(page.items.map { FollowListRow(id: $0.accountId, name: $0.name.value, avatarURL: $0.avatar?.url) }, next: page.nextCursor, hasMore: page.hasMore, append: append)
            case .following:
                let page = try await followService.following(of: accountId, cursor: cursor)
                apply(page.items.map { FollowListRow(id: $0.accountId, name: $0.name.value, avatarURL: $0.avatar?.url) }, next: page.nextCursor, hasMore: page.hasMore, append: append)
            }
        } catch {
            if !append {
                errorMessage = APIError.userMessage(for: error)
            }
        }
    }

    private func apply(_ items: [FollowListRow], next: String?, hasMore: Bool, append: Bool) {
        if append { rows.append(contentsOf: items) } else { rows = items }
        nextCursor = next
        self.hasMore = hasMore
    }
}
