import SwiftUI

/// Avatar + username pair shown above every post and comment.
///
/// Reads the account straight out of `AccountCache` rather than keeping a private copy,
/// so editing your own profile updates every row already on screen. The previous version
/// held a local copy and re-ran its fetch keyed on `feedRefreshSignal.version`, which
/// meant every author row in the app invalidated and re-fetched on every post or comment.
struct AuthorRowView: View {
    let accountId: UUID
    var avatarSize: CGFloat = 36
    /// A trailing timestamp, set by the feed row. Passed in rather than read here so this
    /// view stays a pure identity pair and the caller owns what sits opposite it.
    var trailingText: String? = nil
    var showsChevron: Bool = false
    @Environment(AppEnvironment.self) private var environment

    private var account: AccountSummaryDto? { environment.accountCache.accounts[accountId] }

    var body: some View {
        HStack(spacing: BumpSpacing.s) {
            AvatarView(url: account?.avatar?.url, size: avatarSize)

            Text(account?.name.value ?? "        ")
                .font(BumpFont.subheadline)
                .foregroundStyle(BumpColor.textPrimary)
                .lineLimit(1)
                .redacted(reason: account == nil ? .placeholder : [])

            if let trailingText {
                // A dot leader instead of pushing the timestamp to the far edge: it keeps
                // the name and its age as one readable phrase rather than two things at
                // opposite ends of a wide row.
                // `verbatim:` — a bare separator glyph is punctuation, not copy, and
                // without this it is extracted into the localisation catalogue as a
                // translatable string called "·".
                Text(verbatim: "·")
                    .font(BumpFont.meta)
                    .foregroundStyle(BumpColor.textTertiary)
                    .accessibilityHidden(true)
                Text(trailingText)
                    .font(BumpFont.meta)
                    .foregroundStyle(BumpColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: BumpSpacing.xs)

            if showsChevron {
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
