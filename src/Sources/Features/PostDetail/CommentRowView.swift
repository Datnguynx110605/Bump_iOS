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

    /// Everything below the author line is indented to start under the *name*, not under
    /// the avatar. Without it a comment reads as a caption that happens to follow a face:
    /// the body ran the full width of the screen while the divider between comments was
    /// already inset past the avatar, so the text crossed a rail the list had drawn.
    static let contentInset: CGFloat = 36 + BumpSpacing.s

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                NavigationLink(value: AppRoute.account(comment.accountId)) {
                    AuthorRowView(accountId: comment.accountId)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                if let content = comment.content, !content.isEmpty {
                    Text(content)
                        .font(BumpFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !comment.images.isEmpty {
                    PostImageCarousel(imageURLs: comment.images.map(\.url))
                }

                HStack(spacing: BumpSpacing.xs) {
                    // The toggle centres a 17pt glyph inside a 44pt tap target, so without
                    // pulling that slack back the heart would start 13pt right of the text
                    // column it belongs to.
                    //
                    // Heart and count as one unit, the same way `PostDetailView.likePair`
                    // does it: `.bumpIcon` centres the digit in a 44pt box, which parked it
                    // equidistant from the heart and the timestamp so it read as belonging to
                    // neither. The tap area grows trailing instead, keeping the full target.
                    HStack(spacing: 0) {
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
                                .font(BumpFont.meta)
                                .foregroundStyle(BumpColor.textSecondary)
                                .contentTransition(.numericText())
                                .padding(.trailing, BumpSpacing.m)
                                .frame(minHeight: BumpHitTarget.min)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.bumpSurface)
                        .accessibilityLabel(String(localized: "See who liked this"))
                        .accessibilityValue(Text("\(displayedLikeCount)"))
                    }
                    .padding(.leading, -(BumpHitTarget.min - BumpIconSize.small) / 2)

                    Text(comment.createdAt.relativeDescription)
                        .font(BumpFont.meta)
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
                            Button("Block author", systemImage: "hand.raised", role: .destructive) {
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
            .padding(.leading, Self.contentInset)
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
