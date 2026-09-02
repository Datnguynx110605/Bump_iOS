import SwiftUI

struct CommentRowView: View {
    let comment: CommentSummaryDto
    var onDelete: (() -> Void)? = nil
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSession.self) private var authSession
    @State private var displayedLikeCount: Int
    @State private var isLiked = false
    @State private var showingReportSheet = false
    @ScaledMetric private var reactionIconSize: CGFloat = BumpIconSize.small
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

            HStack(spacing: BumpSpacing.m) {
                HStack(spacing: BumpSpacing.xs) {
                    Button {
                        Task {
                            let liked = await environment.reactionStore.toggleComment(comment.id)
                            isLiked = liked
                            displayedLikeCount += liked ? 1 : -1
                            if liked {
                                HapticFeedback.reacted()
                            }
                        }
                    } label: {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: reactionIconSize))
                            .foregroundStyle(isLiked ? BumpColor.like : BumpColor.textSecondary)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: AppRoute.commentReactors(comment.id)) {
                        Text("\(displayedLikeCount)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BumpColor.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(comment.createdAt.relativeDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

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
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task { isLiked = environment.reactionStore.isLiked(comment: comment.id) }
        .sheet(isPresented: $showingReportSheet) {
            ReportSheet(target: .comment(comment.id))
        }
    }
}
