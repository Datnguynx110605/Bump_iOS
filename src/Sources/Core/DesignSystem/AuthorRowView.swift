import SwiftUI

/// Avatar + username pair shown above every post and comment.
///
/// Reads the account straight out of `AccountCache` rather than keeping a private copy,
/// so editing your own profile updates every row already on screen. The previous version
/// held a local copy and re-ran its fetch keyed on `feedRefreshSignal.version`, which
/// meant every author row in the app invalidated and re-fetched on every post or comment.
struct AuthorRowView: View {
    let accountId: UUID
    var avatarSize: CGFloat = 32
    var showsChevron: Bool = false
    @Environment(AppEnvironment.self) private var environment

    private var account: AccountSummaryDto? { environment.accountCache.accounts[accountId] }

    var body: some View {
        HStack(spacing: BumpSpacing.s) {
            AvatarView(url: account?.avatar?.url, size: avatarSize)
            Text(account?.name.value ?? "        ")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BumpColor.textPrimary)
                .lineLimit(1)
                .redacted(reason: account == nil ? .placeholder : [])
            if showsChevron {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BumpColor.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .task(id: accountId) {
            _ = await environment.accountCache.account(accountId)
        }
    }
}
