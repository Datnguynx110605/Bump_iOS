import SwiftUI

struct CommentRowView: View {
    let comment: CommentSummaryDto
    var onDelete: (() -> Void)? = nil
    /// Called with the saved text so the owning list can update in place rather than
    /// refetching the whole page behind the sheet.
    var onEdited: ((String) -> Void)? = nil
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSession.self) private var authSession
    @State private var displayedLikeCount: Int
    @State private var isLiked = false
    @State private var showingReportSheet = false
    @State private var showingEditSheet = false
    @State private var showingBlockConfirm = false
    @ScaledMetric private var menuIconSize: CGFloat = BumpIconSize.small

    private var isMine: Bool { comment.accountId == authSession.accountId }

    init(comment: CommentSummaryDto, onDelete: (() -> Void)? = nil, onEdited: ((String) -> Void)? = nil) {
        self.comment = comment
        self.onDelete = onDelete
        self.onEdited = onEdited
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
                    if isMine {
                        if onEdited != nil {
                            Button("Edit", systemImage: "pencil") { showingEditSheet = true }
                        }
                        if let onDelete {
                            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                        }
                    } else {
                        Button("Report", systemImage: "flag") { showingReportSheet = true }
                        Button("Block Author", systemImage: "hand.raised", role: .destructive) {
                            showingBlockConfirm = true
                        }
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
        // `displayedLikeCount` is seeded in `init`, and SwiftUI keys this row on the
        // comment id — which doesn't change across a pull-to-refresh — so without this the
        // count stays at whatever it was when the row was first built. The same defect was
        // fixed for posts in `PostRowView`; comments kept it.
        .onChange(of: comment) { _, newComment in
            displayedLikeCount = newComment.reactionAmount.value
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportSheet(target: .comment(comment.id))
        }
        .sheet(isPresented: $showingEditSheet) {
            EditCommentSheet(comment: comment) { onEdited?($0) }
        }
        .confirmationDialog(
            "Block this account? You won't see their posts or comments, and they won't see yours.",
            isPresented: $showingBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                Task {
                    await environment.blockStore.block(comment.accountId)
                    environment.feedRefreshSignal.bump()
                }
            }
        }
    }
}
