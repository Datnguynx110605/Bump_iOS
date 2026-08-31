import SwiftUI

struct CommentRowView: View {
    let comment: CommentSummaryDto
    var onDelete: (() -> Void)? = nil
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSession.self) private var authSession
    @State private var displayedLikeCount: Int
    @State private var isLiked = false
    @State private var showingReportSheet = false

    init(comment: CommentSummaryDto, onDelete: (() -> Void)? = nil) {
        self.comment = comment
        self.onDelete = onDelete
        _displayedLikeCount = State(initialValue: comment.reactionAmount.value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.xs) {
            NavigationLink(value: AppRoute.account(comment.accountId)) {
                AuthorRowView(accountId: comment.accountId, avatarSize: 28)
            }
            .buttonStyle(.plain)

            if let content = comment.content, !content.isEmpty {
                Text(content)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !comment.images.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: BumpSpacing.xs) {
                        ForEach(comment.images, id: \.url) { image in
                            CachedAsyncImage(url: URL(string: image.url), targetSize: CGSize(width: 96, height: 96)) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                default:
                                    Rectangle().fill(BumpColor.fill)
                                }
                            }
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: BumpRadius.control))
                        }
                    }
                }
            }

            HStack(spacing: BumpSpacing.m) {
                HStack(spacing: 4) {
                    Button {
                        Task {
                            let liked = await environment.reactionStore.toggleComment(comment.id)
                            isLiked = liked
                            displayedLikeCount += liked ? 1 : -1
                            if liked {
                                HapticFeedback.reacted()
                                SoundEffect.confirm.play()
                            }
                        }
                    } label: {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundStyle(isLiked ? .red : .secondary)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: AppRoute.commentReactors(comment.id)) {
                        Text("\(displayedLikeCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(comment.createdAt.relativeDescription)
                    .font(.caption)
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
