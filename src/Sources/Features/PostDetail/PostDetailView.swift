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
                        Button("Edit post", systemImage: "pencil") {
                            showingEditSheet = true
                        }
                        Button("Delete post", systemImage: "trash", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    } else {
                        Button("Report post", systemImage: "flag") {
                            showingReportSheet = true
                        }
                        if viewModel?.post != nil {
                            Button("Block author", systemImage: "hand.raised", role: .destructive) {
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
                .bumpAnimation(BumpMotion.standard, value: viewModel.hasNewComments)
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
        VStack(alignment: .leading, spacing: BumpSpacing.ms) {
            BumpSectionHeader(title: "Comments") {
                if let count = viewModel.post?.commentAmount.value, count > 0 {
                    Text("\(count)")
                        .font(BumpFont.numeric)
                        .foregroundStyle(BumpColor.textSecondary)
                }
            }

            if viewModel.isLoadingComments && viewModel.comments.isEmpty {
                VStack(alignment: .leading, spacing: BumpSpacing.m) {
                    ForEach(0..<2, id: \.self) { _ in
                        HStack(alignment: .top, spacing: BumpSpacing.s) {
                            Circle().fill(BumpColor.fill).frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: BumpSpacing.s) {
                                BumpSkeletonBlock(width: 100, height: 11)
                                BumpSkeletonBlock(height: 11)
                            }
                        }
                    }
                }
                .padding(.horizontal, BumpSpacing.m)
                .padding(.vertical, BumpSpacing.s)
            } else if comments.isEmpty {
                Text("No comments yet — be the first to say something kind.")
                    .font(BumpFont.callout)
                    .foregroundStyle(BumpColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, BumpSpacing.m)
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
                        .padding(.horizontal, BumpSpacing.m)
                        .padding(.vertical, BumpSpacing.ms)
                        .task { await viewModel.loadMoreCommentsIfNeeded(current: comment) }

                        if comment.id != comments.last?.id {
                            BumpDivider(inset: BumpSpacing.m + CommentRowView.contentInset)
                        }
                    }
                }
                if viewModel.isLoadingMoreComments {
                    ProgressView()
                        .tint(BumpColor.brand)
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

    /// The comment bar.
    ///
    /// Opaque `surface` with a hairline on top, **not** `.bar`. `.bar` is a system
    /// material — it blurs the comments scrolling behind it, which is precisely the
    /// translucent chrome this design language removes everywhere else.
    private var composer: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.s) {
            BumpDivider()

            if !viewModel.selectedCommentImages.isEmpty {
                attachmentStrip
            }

            HStack(alignment: .bottom, spacing: BumpSpacing.xs) {
                SquarePhotoAttachmentPicker(images: $viewModel.selectedCommentImages, maxCount: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: BumpIconSize.medium, weight: .light))
                        .foregroundStyle(BumpColor.textSecondary)
                        .frame(minWidth: BumpHitTarget.min, minHeight: BumpHitTarget.min)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "Add photos"))

                TextField("Say something nice…", text: $viewModel.commentDraft, axis: .vertical)
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
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(BumpFont.subheadline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .background(canSubmitComment ? BumpColor.brandFill : BumpColor.fill, in: Circle())
                    .bumpAnimation(BumpMotion.quick, value: canSubmitComment)
                }
                .buttonStyle(.bumpIcon)
                .disabled(!canSubmitComment)
                .accessibilityLabel(String(localized: "Send comment"))
            }
            .padding(.horizontal, BumpSpacing.m)
        }
        .padding(.bottom, BumpSpacing.s)
        .background(BumpColor.surface)
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

/// "New comments" jump-to-top affordance. A filled pill with no shadow — it already
/// separates from the page by being the only saturated object on it.
private struct NewCommentsPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("New comments", systemImage: "arrow.up")
                .font(BumpFont.control)
                .foregroundStyle(.white)
                .padding(.horizontal, BumpSpacing.m)
                .frame(minHeight: BumpHitTarget.min)
                .background(BumpColor.brandFill, in: Capsule())
        }
        .buttonStyle(.bumpSurface)
    }
}

private struct PostHeaderSection: View {
    let post: PostSummaryDto
    /// Kept as properties, not just `init` arguments: neither flag lives on
    /// `PostSummaryDto`, so `onChange(of: post)` can never see them move. Without
    /// something to observe, a refresh updated the like count while the heart and
    /// bookmark kept rendering whatever they showed on first build.
    let isReacted: Bool
    let isSavedByViewer: Bool
    @Environment(AppEnvironment.self) private var environment
    @State private var shop: ShopDto?
    @State private var displayedLikeCount: Int
    @State private var isLiked: Bool
    @State private var isSaved: Bool

    init(post: PostSummaryDto, isReacted: Bool, isSaved: Bool) {
        self.post = post
        self.isReacted = isReacted
        self.isSavedByViewer = isSaved
        _displayedLikeCount = State(initialValue: post.reactionAmount.value)
        _isLiked = State(initialValue: isReacted)
        _isSaved = State(initialValue: isSaved)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.m) {
            NavigationLink(value: AppRoute.account(post.accountId)) {
                AuthorRowView(
                    accountId: post.accountId,
                    trailingText: post.createdAt.relativeDescription,
                    showsChevron: true
                )
                .padding(.horizontal, BumpSpacing.m)
            }
            .buttonStyle(.bumpSurface)

            // Edge to edge: the photo is the subject of this screen, so it gets the
            // full width rather than sitting inside the text gutter.
            if !post.images.isEmpty {
                PostImageCarousel(imageURLs: post.images.map(\.url))
            }

            actionBar
                .padding(.horizontal, BumpSpacing.s)

            VStack(alignment: .leading, spacing: BumpSpacing.m) {
                if let caption = post.caption, !caption.isEmpty {
                    Text(caption)
                        .font(BumpFont.body)
                        .foregroundStyle(BumpColor.textPrimary)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                shopBlock
            }
            .padding(.horizontal, BumpSpacing.m)
        }
        .task {
            environment.reactionStore.setLiked(post: post.id, isLiked)
            environment.saveStore.setSaved(post: post.id, isSaved)
            if shop == nil { shop = await environment.shopCache.shop(post.shopId) }
        }
        // Pull-to-refresh replaces the post but not this view's identity, so everything
        // seeded in `init` has to be re-read explicitly.
        .onChange(of: post) { _, newPost in
            displayedLikeCount = newPost.reactionAmount.value
        }
        .onChange(of: isReacted) { _, newValue in
            isLiked = newValue
            environment.reactionStore.setLiked(post: post.id, newValue)
        }
        .onChange(of: isSavedByViewer) { _, newValue in
            isSaved = newValue
            environment.saveStore.setSaved(post: post.id, newValue)
        }
    }

    /// Directly under the photo, matching the feed row, so the like button lives in the
    /// same place whether the user is scrolling past a post or reading it.
    private var actionBar: some View {
        HStack(spacing: BumpSpacing.xs) {
            likePair

            ReactionCountLabel(
                systemImage: "bubble.right",
                count: post.commentAmount.value,
                accessibilityLabel: String(localized: "Comments")
            )

            Spacer()

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

    /// The heart and its count, as one unit.
    ///
    /// They are two different actions — the heart toggles the like, the number opens the
    /// list of who liked it — but they are one *thing*, and the layout has to say so.
    ///
    /// `spacing: 0` and a trailing-only tap extension are what does it. The count used to
    /// carry `.buttonStyle(.bumpIcon)`, which stretches its content to a 44pt-wide box and
    /// **centres** it: correct for an icon-only control, wrong for a digit, because it
    /// parked ~17pt of dead space on each side. The number ended up 48pt from the heart
    /// and 48pt from the comment bubble — exactly equidistant, so it read as belonging to
    /// neither. Growing the hit area away from the heart instead keeps the digit beside
    /// the glyph it counts; the extension is full-height but only ~26pt wide, because any
    /// more pushes the comment bubble off the spacing the feed row uses.
    private var likePair: some View {
        HStack(spacing: 0) {
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
                    .font(BumpFont.numeric)
                    .foregroundStyle(BumpColor.textSecondary)
                    .contentTransition(.numericText())
                    .padding(.trailing, BumpSpacing.s)
                    .frame(minHeight: BumpHitTarget.min)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.bumpSurface)
            .accessibilityLabel(String(localized: "See who liked this"))
            .accessibilityValue(Text("\(displayedLikeCount)"))
        }
    }

    /// The place being reviewed, as one flat tonal block: name, address, rating, and a
    /// route out to Maps. Grouped so it reads as a single object rather than four loose
    /// lines, and tonal rather than carded so it stays part of the page.
    private var shopBlock: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.s) {
            NavigationLink(value: AppRoute.shop(post.shopId)) {
                HStack(alignment: .firstTextBaseline, spacing: BumpSpacing.s) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shop?.name ?? String(localized: "Finding the spot…"))
                            .font(BumpFont.headline)
                            .foregroundStyle(BumpColor.textPrimary)
                            .redacted(reason: shop == nil ? .placeholder : [])
                        if let address = shop?.address {
                            Text(address)
                                .font(BumpFont.meta)
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
            .buttonStyle(.bumpSurface)

            if let shop {
                BumpDivider()
                Button {
                    AppleMaps.openDirections(placeId: shop.placeId, shopName: shop.name, address: shop.address)
                } label: {
                    Label("Get directions", systemImage: "arrow.triangle.turn.up.right.circle")
                }
                .buttonStyle(.bumpText)
            }
        }
        .bumpCard()
    }
}
