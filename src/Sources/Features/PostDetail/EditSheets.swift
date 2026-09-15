import SwiftUI

/// Edit a post's caption and rating.
///
/// The server splits these across two endpoints (`PUT /Post/{id}/caption` and
/// `PUT /Post/{id}/rate`) but the user thinks of them as one edit, so they share a sheet
/// and only the fields that actually changed are sent — the same shape `EditProfileView`
/// already uses for name and bio.
struct EditPostSheet: View {
    let post: PostSummaryDto
    /// Called after a successful save so the presenting screen can reload.
    var onSaved: () async -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var caption: String
    @State private var rating: Int
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(post: PostSummaryDto, onSaved: @escaping () async -> Void) {
        self.post = post
        self.onSaved = onSaved
        _caption = State(initialValue: post.caption ?? "")
        _rating = State(initialValue: post.rate.value)
    }

    private var hasChanges: Bool {
        caption != (post.caption ?? "") || rating != post.rate.value
    }

    private var canSave: Bool {
        hasChanges && FreeTextRule.isValid(caption) && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    RatingPickerView(rating: $rating)
                        .padding(.vertical, BumpSpacing.xs)
                } header: {
                    Text("Your rating").bumpSectionLabel()
                }

                Section {
                    TextField("What made this place worth the trip?", text: $caption, axis: .vertical)
                        .lineLimit(3...8)
                    if let remaining = FreeTextRule.remaining(caption) {
                        FieldHint(
                            text: "\(remaining) characters left",
                            tone: remaining < 0 ? .error : .neutral
                        )
                    }
                } header: {
                    Text("Caption").bumpSectionLabel()
                }

                if let errorMessage {
                    InlineErrorBanner(message: errorMessage)
                        .listRowBackground(Color.clear)
                }
            }
            .listRowBackground(BumpColor.surfaceSecondary)
            .bumpScrollBackground()
            .tint(BumpColor.brand)
            .navigationTitle("Edit post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if caption != (post.caption ?? "") {
                try await environment.postService.changeCaption(postId: post.id, caption: caption)
            }
            if rating != post.rate.value {
                try await environment.postService.changeRate(postId: post.id, rate: rating)
            }
            await onSaved()
            environment.feedRefreshSignal.bump()
            dismiss()
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't save your changes."))
        }
    }
}

/// Edit a comment's text. Photos aren't editable — the server has no endpoint for them —
/// so an image-only comment can gain text here but its images stay as posted.
struct EditCommentSheet: View {
    let comment: CommentSummaryDto
    var onSaved: (String) -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var content: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isContentFocused: Bool

    init(comment: CommentSummaryDto, onSaved: @escaping (String) -> Void) {
        self.comment = comment
        self.onSaved = onSaved
        _content = State(initialValue: comment.content ?? "")
    }

    private var canSave: Bool {
        content != (comment.content ?? "") && FreeTextRule.isValid(content) && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Say something nice", text: $content, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($isContentFocused)
                    if let remaining = FreeTextRule.remaining(content) {
                        FieldHint(
                            text: "\(remaining) characters left",
                            tone: remaining < 0 ? .error : .neutral
                        )
                    }
                } header: {
                    Text("Comment").bumpSectionLabel()
                }

                if !comment.images.isEmpty {
                    Section {
                        FieldHint(text: "Photos can't be changed after posting.")
                    }
                }

                if let errorMessage {
                    InlineErrorBanner(message: errorMessage)
                        .listRowBackground(Color.clear)
                }
            }
            .listRowBackground(BumpColor.surfaceSecondary)
            .bumpScrollBackground()
            .tint(BumpColor.brand)
            .navigationTitle("Edit comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(!canSave)
                }
            }
            .task { isContentFocused = true }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await environment.commentService.changeContent(commentId: comment.id, content: content)
            onSaved(content)
            dismiss()
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't save your changes."))
        }
    }
}
