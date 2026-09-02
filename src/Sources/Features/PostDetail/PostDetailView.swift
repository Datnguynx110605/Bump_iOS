import SwiftUI
import UIKit

private let commentPollInterval: Duration = .seconds(20)

struct PostDetailView: View {
    let postId: UUID
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSession.self) private var authSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: PostDetailViewModel?
    @State private var showingReportSheet = false
    @State private var showingDeleteConfirm = false
    @State private var isVisible = false

    var body: some View {
        Group {
            if let viewModel {
                PostDetailContent(viewModel: viewModel, showingReportSheet: $showingReportSheet)
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
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .task(id: "\(isVisible)-\(scenePhase == .active)") {
            guard isVisible, scenePhase == .active else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: commentPollInterval)
                if Task.isCancelled { return }
                await viewModel?.checkForNewComments()
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let post = viewModel?.post, post.accountId == authSession.accountId {
                        Button("Delete Post", systemImage: "trash", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    } else {
                        Button("Report Post", systemImage: "flag") {
                            showingReportSheet = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Delete this post?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await viewModel?.deletePost() }
            }
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportSheet(target: .post(postId))
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
                    VStack(alignment: .leading, spacing: BumpSpacing.m) {
                        PostHeaderSection(post: post, isReacted: viewModel.isReacted, isSaved: viewModel.isSaved)
                        Divider()
                        commentsSection
                    }
                    .padding(BumpSpacing.m)
                }
                .refreshable { await viewModel.refresh() }
                .safeAreaInset(edge: .top) {
                    if viewModel.hasNewComments {
                        NewCommentsPill { Task { await viewModel.loadComments() } }
                            .padding(.top, BumpSpacing.s)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(BumpMotion.quick, value: viewModel.hasNewComments)
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

    @ViewBuilder
    private var commentsSection: some View {
        Text("Comments")
            .font(.headline)

        if viewModel.isLoadingComments && viewModel.comments.isEmpty {
            ProgressView().frame(maxWidth: .infinity)
        } else if viewModel.comments.isEmpty {
            Text("No comments yet. Say something nice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ForEach(viewModel.comments) { comment in
                CommentRowView(comment: comment, onDelete: {
                    Task {
                        await viewModel.deleteComment(comment)
                        environment.feedRefreshSignal.bump()
                    }
                })
                .task { await viewModel.loadMoreCommentsIfNeeded(current: comment) }
                Divider()
            }
            if viewModel.isLoadingMoreComments {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.xs) {
            if !viewModel.selectedCommentImages.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: BumpSpacing.xs) {
                        ForEach(Array(viewModel.selectedCommentImages.enumerated()), id: \.offset) { _, data in
                            if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: BumpRadius.control))
                            }
                        }
                    }
                }
                .padding(.horizontal, BumpSpacing.m)
            }

            HStack(spacing: BumpSpacing.s) {
                SquarePhotoAttachmentPicker(images: $viewModel.selectedCommentImages, maxCount: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(.title2))
                        .foregroundStyle(.secondary)
                }

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
                    if viewModel.isSubmittingComment {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(.largeTitle))
                    }
                }
                .disabled(
                    (viewModel.commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && viewModel.selectedCommentImages.isEmpty)
                    || viewModel.isSubmittingComment)
            }
            .padding(.horizontal, BumpSpacing.m)
        }
        .padding(.vertical, BumpSpacing.s)
        .background(.bar)
    }
}

private struct NewCommentsPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("New comments", systemImage: "arrow.up.circle.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, BumpSpacing.m)
                .padding(.vertical, BumpSpacing.s)
                .background(BumpColor.brand, in: Capsule())
                .foregroundStyle(.white)
                .shadow(radius: 4, y: 2)
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
    @ScaledMetric private var reactionIconSize: CGFloat = BumpIconSize.medium
    @ScaledMetric private var bookmarkIconSize: CGFloat = BumpIconSize.medium

    init(post: PostSummaryDto, isReacted: Bool, isSaved: Bool) {
        self.post = post
        _displayedLikeCount = State(initialValue: post.reactionAmount.value)
        _isLiked = State(initialValue: isReacted)
        _isSaved = State(initialValue: isSaved)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.m) {
            NavigationLink(value: AppRoute.account(post.accountId)) {
                AuthorRowView(accountId: post.accountId, showsChevron: true)
            }
            .buttonStyle(.plain)

            if !post.images.isEmpty {
                PostImageCarousel(imageURLs: post.images.map(\.url))
            }

            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                NavigationLink(value: AppRoute.shop(post.shopId)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shop?.name ?? String(localized: "Loading shop…"))
                                .font(.headline)
                                .redacted(reason: shop == nil ? .placeholder : [])
                            if let address = shop?.address {
                                Text(address)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        RatingStarsView(rating: post.rate.value)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                if let shop {
                    Button {
                        AppleMaps.openDirections(shopName: shop.name, address: shop.address)
                    } label: {
                        Label("View in Map", systemImage: "map")
                            .font(.footnote.weight(.medium))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.body)
            }

            HStack(spacing: BumpSpacing.l) {
                HStack(spacing: BumpSpacing.xs) {
                    Button {
                        Task {
                            let liked = await environment.reactionStore.togglePost(post.id)
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

                    NavigationLink(value: AppRoute.postReactors(post.id)) {
                        Text("\(displayedLikeCount)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BumpColor.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                ReactionCountLabel(systemImage: "bubble.right", count: post.commentAmount.value)

                Spacer()

                Text(post.createdAt.relativeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task { isSaved = await environment.saveStore.togglePost(post.id) }
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: bookmarkIconSize))
                        .foregroundStyle(isSaved ? Color.accentColor : BumpColor.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            environment.reactionStore.setLiked(post: post.id, isLiked)
            environment.saveStore.setSaved(post: post.id, isSaved)
            if shop == nil { shop = await environment.shopCache.shop(post.shopId) }
        }
    }
}
