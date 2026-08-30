import SwiftUI

struct AuthorRowView: View {
    let accountId: UUID
    var avatarSize: CGFloat = 32
    var showsChevron: Bool = false
    @Environment(AppEnvironment.self) private var environment
    @State private var account: AccountSummaryDto?

    var body: some View {
        HStack(spacing: BumpSpacing.s) {
            AvatarView(url: account?.avatar?.url, size: avatarSize)
            Text(account?.name.value ?? "…")
                .font(.subheadline.weight(.semibold))
                .redacted(reason: account == nil ? .placeholder : [])
            if showsChevron {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: environment.feedRefreshSignal.version) {
            account = await environment.accountCache.account(accountId)
        }
    }
}
