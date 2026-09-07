import SwiftUI

struct CommentRowView: View {
    let comment: CommentSummaryDto
    var onDelete: (() -> Void)? = nil
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSession.self) private var authSession
    @State private var displayedLikeCount: Int
    @State private var isLiked = false
    @State private var showingReportSheet = false
    @ScaledMetric private var menuIconSize: CGFloat = BumpIconSize.small

    init(comment: CommentSummaryDto, onDelete: (() -> Void)? = nil) {
        self.comment = comment
        self.onDelete = onDelete
        _displayedLikeCount = State(initialValue: comment.reactionAmount.value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.xs) {
            NavigationLink(value: AppRoute.account(comment.accountId)) {
                AuthorRowView(accountId: comment.accountId)
            }
            .buttonStyle(.plain)

            if let content = comment.content, !content.isEmpty {
                Text(content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !comment.images.isEmpty {
                PostImageCarousel(imageURLs: comment.images.map(\.url))
            }

            HStack(spacing: BumpSpacing.xs) {
                BumpToggleIconButton(
                    isOn: isLiked,
                    onImage: "heart.fill",
                    offImage: "heart",
                    label: isLiked ? String(localized: "Unlike comment") : String(localized: "Like comment"),
                    activeColor: BumpColor.like,
                    size: BumpIconSize.small
                ) {
                    Task {
                        let toggle = await environment.reactionStore.toggleComment(comment.id)
                        isLiked = toggle.isLiked
                        displayedLikeCount += toggle.countDelta
                        if toggle.countDelta > 0 { HapticFeedback.reacted() }
                    }
                }

                NavigationLink(value: AppRoute.commentReactors(comment.id)) {
                    Text("\(displayedLikeCount)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BumpColor.textSecondary)
                        .contentTransition(.numericText())
                }
                .buttonStyle(.bumpIcon)
                .accessibilityLabel(String(localized: "See who liked this"))
                .accessibilityValue(Text("\(displayedLikeCount)"))

                Text(comment.createdAt.relativeDescription)
                    .font(.footnote)
                    .foregroundStyle(BumpColor.textSecondary)

                Spacer()

                Menu {
                    if comment.accountId == authSession.accountId, let onDelete {
                        Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                    } else {
                        Button("Report", systemImage: "flag") { showingReportSheet = true }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: menuIconSize))
                        .foregroundStyle(BumpColor.textSecondary)
                        .frame(minWidth: BumpHitTarget.min, minHeight: BumpHitTarget.min)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "More actions"))
            }
        }
        .task { isLiked = environment.reactionStore.isLiked(comment: comment.id) }
        .sheet(isPresented: $showingReportSheet) {
            ReportSheet(target: .comment(comment.id))
        }
    }
}
