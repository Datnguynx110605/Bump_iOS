import Foundation

@MainActor
@Observable
final class PostDetailViewModel {
    let postId: UUID

    var post: PostSummaryDto?
    var isReacted = false
    var isSaved = false
    var comments: [CommentSummaryDto] = []
    var isLoadingPost = false
    var isLoadingComments = false
    var isLoadingMoreComments = false
    var isSubmittingComment = false
    var errorMessage: String?
    var commentDraft = ""
    var didDelete = false
    var hasNewComments = false

    var selectedCommentImages: [Data] = []

    private var nextCommentsCursor: String?
    private var hasMoreComments = true
    private var topCommentId: UUID?
    private let postService: PostService
    private let commentService: CommentService

    init(postId: UUID, postService: PostService, commentService: CommentService) {
        self.postId = postId
        self.postService = postService
        self.commentService = commentService
    }

    func loadIfNeeded() async {
        if post == nil { await loadPost() }
        if comments.isEmpty { await loadComments() }
    }

    func refresh() async {
        await loadPost()
        nextCommentsCursor = nil
        hasMoreComments = true
        await loadComments()
    }

    func loadPost() async {
        isLoadingPost = true
        errorMessage = nil
        defer { isLoadingPost = false }
        do {
            let item = try await postService.post(id: postId)
            post = item.post
            isReacted = item.isReacted
            isSaved = item.isSaved
        } catch {
            errorMessage = APIError.userMessage(for: error)
        }
    }

    func loadComments() async {
        isLoadingComments = true
        defer { isLoadingComments = false }
        do {
            let page = try await commentService.byPost(postId, cursor: nil)
            comments = page.items
            nextCommentsCursor = page.nextCursor
            hasMoreComments = page.hasMore
            topCommentId = page.items.first?.id
            hasNewComments = false
        } catch {
        }
    }

    /// Cheap single-item probe used for battery-friendly polling while this post is open.
    func checkForNewComments() async {
        guard !isLoadingComments else { return }
        guard let page = try? await commentService.byPost(postId, cursor: nil, pageSize: 1) else { return }
        if let latestId = page.items.first?.id, latestId != topCommentId {
            hasNewComments = true
        }
    }

    func loadMoreCommentsIfNeeded(current: CommentSummaryDto) async {
        guard hasMoreComments, !isLoadingMoreComments, comments.isNearEnd(current) else { return }
        isLoadingMoreComments = true
        defer { isLoadingMoreComments = false }
        do {
            let page = try await commentService.byPost(postId, cursor: nextCommentsCursor)
            comments.append(contentsOf: page.items)
            nextCommentsCursor = page.nextCursor
            hasMoreComments = page.hasMore
        } catch {
        }
    }

    func submitComment() async {
        let trimmed = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !selectedCommentImages.isEmpty, !isSubmittingComment else { return }
        isSubmittingComment = true
        defer { isSubmittingComment = false }
        do {
            let uploads = selectedCommentImages.map { ImageUpload(filename: "photo.jpg", mimeType: "image/jpeg", data: $0) }
            let created = try await commentService.create(
                postId: postId,
                content: trimmed.isEmpty ? nil : trimmed,
                images: uploads)
            comments.insert(CommentSummaryDto(
                id: created.id,
                accountId: created.accountId,
                content: created.content,
                images: created.images,
                reactionAmount: created.reactionAmount,
                createdAt: created.createdAt
            ), at: 0)
            topCommentId = comments.first?.id
            hasNewComments = false
            commentDraft = ""
            selectedCommentImages = []
            SoundEffect.sent.play()
            HapticFeedback.succeeded()
            await loadPost()
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't post your comment."))
        }
    }

    func updateComment(_ comment: CommentSummaryDto, content: String) {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        comments[index] = comment.withContent(content)
    }

    func deleteComment(_ comment: CommentSummaryDto) async {
        do {
            try await commentService.delete(commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
            topCommentId = comments.first?.id
            await loadPost()
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't delete that comment."))
        }
    }

    func deletePost() async {
        do {
            try await postService.delete(postId: postId)
            didDelete = true
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't delete this post."))
        }
    }
}
