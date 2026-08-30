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

    var selectedCommentImages: [Data] = []

    private var nextCommentsCursor: String?
    private var hasMoreComments = true
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
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
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
        } catch {
        }
    }

    func loadMoreCommentsIfNeeded(current: CommentSummaryDto) async {
        guard hasMoreComments, !isLoadingMoreComments, comments.last?.id == current.id else { return }
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
            commentDraft = ""
            selectedCommentImages = []
            await loadPost()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't post your comment."
        }
    }

    func deleteComment(_ comment: CommentSummaryDto) async {
        do {
            try await commentService.delete(commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
            await loadPost()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't delete that comment."
        }
    }

    func deletePost() async {
        do {
            try await postService.delete(postId: postId)
            didDelete = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't delete this post."
        }
    }
}
