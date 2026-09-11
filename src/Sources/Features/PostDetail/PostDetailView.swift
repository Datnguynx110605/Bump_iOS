import SwiftUI
import UIKit

private let commentPollInterval: Duration = .seconds(20)

struct PostDetailView: View {
    let postId: UUID
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSession.self) private var authSession
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PostDetailViewModel?
    @State private var showingReportSheet = false
    @State private var showingDeleteConfirm = false
    @State private var showingEditSheet = false
    @State private var showingBlockConfirm = false

    var body: some View {
        Group {
            if let viewModel {
                PostDetailContent(viewModel: viewModel, showingReportSheet: $showingReportSheet)
                    .autoRefresh(every: commentPollInterval) { await viewModel.checkForNewComments() }
                    .onChange(of: viewModel.didDelete) { _, didDelete in
                        if didDelete {
                            environment.feedRefreshSignal.bump()
                            dismiss()
                        }
                    }
            } else {
                LoadingView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = PostDetailViewModel(
                    postId: postId,
                    postService: environment.postService,
                    commentService: environment.commentService
                )
            }
            await viewModel?.loadIfNeeded()
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let post = viewModel?.post, post.accountId == authSession.accountId {
                        Button("Edit Post", systemImage: "pencil") {
                            showingEditSheet = true
                        }
                        Button("Delete Post", systemImage: "trash", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    } else {
                        Button("Report Post", systemImage: "flag") {
                            showingReportSheet = true
                        }
                        if viewModel?.post != nil {
                            Button("Block Author", systemImage: "hand.raised", role: .destructive) {
                                showingBlockConfirm = true
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(String(localized: "More actions"))
            }
        }
        .confirmationDialog("Delete this post?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await viewModel?.deletePost() }
            }
        }
        .confirmationDialog(
            "Block this account? You won't see their posts or comments, and they won't see yours.",
            isPresented: $showingBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                guard let authorId = viewModel?.post?.accountId else { return }
                Task {
                    await environment.blockStore.block(authorId)
                    environment.feedRefreshSignal.bump()
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportSheet(target: .post(postId))
        }
        .sheet(isPresented: $showingEditSheet) {
            if let post = viewModel?.post {
                EditPostSheet(post: post) { await viewModel?.loadPost() }
            }
        }
    }
}

private struct PostDetailContent: View {
    @Bindable var viewModel: PostDetailViewModel
    @Binding var showingReportSheet: Bool
    @Environment(AppEnvironment.self) private var environment
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let post = viewModel.post {
                ScrollView {
                    VStack(alignment: .leading, spacing: BumpSpacing.l) {
                        PostHeaderSection(post: post, isReacted: viewModel.isReacted, isSaved: viewModel.isSaved)
                        commentsSection
                            .padding(.horizontal, BumpSpacing.m)
                    }
                    .padding(.bottom, BumpSpacing.m)
                }
                .background(BumpColor.surface)
                .refreshable { await viewModel.refresh() }
                .safeAreaInset(edge: .top) {
                    if viewModel.hasNewComments {
                        NewCommentsPill { Task { await viewModel.loadComments() } }
                            .padding(.top, BumpSpacing.s)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .bumpAnimation(BumpMotion.quick, value: viewModel.hasNewComments)
            } else if viewModel.isLoadingPost {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                ErrorStateView(message: errorMessage) { Task { await viewModel.loadIfNeeded() } }
            }

            if viewModel.post != nil {
                composer
            }
        }
    }

    /// A block takes effect server-side only once the queued consumer has run, so a
    /// comment from someone just blocked is still in the page the screen is holding.
    /// Hiding it here is what makes the action feel like it happened.
    private var visibleComments: [CommentSummaryDto] {
        environment.blockStore.visible(viewModel.comments) { $0.accountId }
    }

    @ViewBuilder
    private var commentsSection: some View {
        // Filtered once per body pass. Read straight from `visibleComments` inside the
        // ForEach and the whole list gets re-filtered on every row's divider check.
        let comments = visibleComments
        VStack(alignment: .leading, spacing: BumpSpacing.m) {
            HStack(spacing: BumpSpacing.s) {
                Text("Comments")
                    .font(.headline)
                if let count = viewModel.post?.commentAmount.value, count > 0 {
                    Text("\(count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BumpColor.textSecondary)
                        .padding(.horizontal, BumpSpacing.s)
                        .padding(.vertical, BumpSpacing.xs)
                        .background(BumpColor.surfaceTertiary, in: Capsule())
                }
            }
            .accessibilityElement(children: .combine)

            if viewModel.isLoadingComments && viewModel.comments.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BumpSpacing.l)
            } else if comments.isEmpty {
                Text("No comments yet. Say something nice.")
                    .font(.subheadline)
                    .foregroundStyle(BumpColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, BumpSpacing.m)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(comments) { comment in
                        CommentRowView(
                            comment: comment,
                            onDelete: {
                                Task {
                                    await viewModel.deleteComment(comment)
                                    environment.feedRefreshSignal.bump()
                                }
                            },
                            onEdited: { viewModel.updateComment(comment, content: $0) }
                        )
                        .padding(.vertical, BumpSpacing.ms)
                        .task { await viewModel.loadMoreCommentsIfNeeded(current: comment) }

                        if comment.id != comments.last?.id {
                            Divider()
                        }
                    }
                }
                if viewModel.isLoadingMoreComments {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BumpSpacing.m)
                }
            }
        }
    }

    private var canSubmitComment: Bool {
        !(viewModel.commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && viewModel.selectedCommentImages.isEmpty)
            && !viewModel.isSubmittingComment
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.s) {
            if !viewModel.selectedCommentImages.isEmpty {
                attachmentStrip
            }

            HStack(alignment: .bottom, spacing: BumpSpacing.xs) {
                SquarePhotoAttachmentPicker(images: $viewModel.selectedCommentImages, maxCount: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: BumpIconSize.medium))
                        .foregroundStyle(BumpColor.textSecondary)
                        .frame(minWidth: BumpHitTarget.min, minHeight: BumpHitTarget.min)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "Add photos"))

                TextField("Add a comment…", text: $viewModel.commentDraft, axis: .vertical)
                    .textFieldStyle(.bump)
                    .lineLimit(1...4)
                    .focused($isComposerFocused)

                Button {
                    Task {
                        await viewModel.submitComment()
                        environment.feedRefreshSignal.bump()
                    }
                } label: {
                    Group {
                        if viewModel.isSubmittingComment {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .background(canSubmitComment ? BumpColor.brandFill : BumpColor.fill, in: Circle())
                }
                .buttonStyle(.bumpIcon)
                .disabled(!canSubmitComment)
                .accessibilityLabel(String(localized: "Send comment"))
            }
            .padding(.horizontal, BumpSpacing.m)
        }
        .padding(.vertical, BumpSpacing.s)
        .background(.bar)
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: BumpSpacing.s) {
                ForEach(Array(viewModel.selectedCommentImages.enumerated()), id: \.offset) { index, data in
                    if let uiImage = UIImage(data: data) {
                        AttachmentThumbnail(image: uiImage, size: 56) {
                            viewModel.selectedCommentImages.remove(at: index)
                        }
                    }
                }
            }
            .padding(.horizontal, BumpSpacing.m)
        }
        .scrollIndicators(.hidden)
    }
}

private struct NewCommentsPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("New comments", systemImage: "arrow.up")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, BumpSpacing.m)
                .frame(minHeight: BumpHitTarget.min)
                .background(BumpColor.brandFill, in: Capsule())
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

private struct PostHeaderSection: View {
    let post: PostSummaryDto
    @Environment(AppEnvironment.self) private var environment
    @State private var shop: ShopDto?
    @State private var displayedLikeCount: Int
    @State private var isLiked: Bool
    @State private var isSaved: Bool

    init(post: PostSummaryDto, isReacted: Bool, isSaved: Bool) {
        self.post = post
        _displayedLikeCount = State(initialValue: post.reactionAmount.value)
        _isLiked = State(initialValue: isReacted)
        _isSaved = State(initialValue: isSaved)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.m) {
            NavigationLink(value: AppRoute.account(post.accountId)) {
                AuthorRowView(accountId: post.accountId, avatarSize: 36, showsChevron: true)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, BumpSpacing.m)

            // Edge to edge: the photo is the subject of this screen, so it gets the
            // full width rather than sitting inside the text gutter.
            if !post.images.isEmpty {
                PostImageCarousel(imageURLs: post.images.map(\.url), cornerRadius: 0)
            }

            VStack(alignment: .leading, spacing: BumpSpacing.m) {
                shopCard

                if let caption = post.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.body)
                        .foregroundStyle(BumpColor.textPrimary)
                }

            HStack(spacing: BumpSpacing.s) {
                BumpToggleIconButton(
                    isOn: isLiked,
                    onImage: "heart.fill",
                    offImage: "heart",
                    label: isLiked ? String(localized: "Unlike") : String(localized: "Like"),
                    activeColor: BumpColor.like
                ) {
                    Task {
                        let toggle = await environment.reactionStore.togglePost(post.id)
                        isLiked = toggle.isLiked
                        displayedLikeCount += toggle.countDelta
                        if toggle.countDelta > 0 { HapticFeedback.reacted() }
                    }
                }

                NavigationLink(value: AppRoute.postReactors(post.id)) {
                    Text("\(displayedLikeCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BumpColor.textSecondary)
                        .contentTransition(.numericText())
                }
                .buttonStyle(.bumpIcon)
                .accessibilityLabel(String(localized: "See who liked this"))
                .accessibilityValue(Text("\(displayedLikeCount)"))

                ReactionCountLabel(
                    systemImage: "bubble.right",
                    count: post.commentAmount.value,
                    accessibilityLabel: String(localized: "Comments")
                )
                .padding(.leading, BumpSpacing.s)

                Spacer()

                Text(post.createdAt.relativeDescription)
                    .font(.caption)
                    .foregroundStyle(BumpColor.textSecondary)

                BumpToggleIconButton(
                    isOn: isSaved,
                    onImage: "bookmark.fill",
                    offImage: "bookmark",
                    label: isSaved ? String(localized: "Remove from saved") : String(localized: "Save post")
                ) {
                    Task { isSaved = await environment.saveStore.togglePost(post.id) }
                }
                }
            }
            .padding(.horizontal, BumpSpacing.m)
        }
        .task {
            environment.reactionStore.setLiked(post: post.id, isLiked)
            environment.saveStore.setSaved(post: post.id, isSaved)
            if shop == nil { shop = await environment.shopCache.shop(post.shopId) }
        }
        // Pull-to-refresh replaces the post but not this view's identity, so the counts
        // seeded in `init` have to be re-read explicitly.
        .onChange(of: post) { _, newPost in
            displayedLikeCount = newPost.reactionAmount.value
        }
    }

    /// Shop name, address, rating and directions grouped into one tappable card, so the
    /// place being reviewed reads as a single object rather than four loose lines.
    private var shopCard: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.s) {
            NavigationLink(value: AppRoute.shop(post.shopId)) {
                HStack(alignment: .firstTextBaseline, spacing: BumpSpacing.s) {
                    VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                        Text(shop?.name ?? String(localized: "Loading shop…"))
                            .font(.headline)
                            .foregroundStyle(BumpColor.textPrimary)
                            .redacted(reason: shop == nil ? .placeholder : [])
                        if let address = shop?.address {
                            Text(address)
                                .font(.footnote)
                                .foregroundStyle(BumpColor.textSecondary)
                        }
                    }
                    Spacer(minLength: BumpSpacing.s)
                    RatingStarsView(rating: post.rate.value, size: BumpIconSize.small)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BumpColor.textTertiary)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)

            if let shop {
                Divider()
                Button {
                    AppleMaps.openDirections(shopName: shop.name, address: shop.address)
                } label: {
                    Label("View in Map", systemImage: "map")
                }
                .buttonStyle(.bumpText)
            }
        }
        .bumpCard()
    }
}
