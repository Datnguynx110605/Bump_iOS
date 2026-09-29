import SwiftUI
import UIKit

struct CreatePostView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreatePostViewModel?
    @State private var showingDiscardConfirm = false

    private var hasUnsavedWork: Bool { viewModel?.hasUnsavedWork == true }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    CreatePostForm(viewModel: viewModel)
                } else {
                    LoadingView()
                }
            }
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasUnsavedWork { showingDiscardConfirm = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await viewModel?.submit() }
                    } label: {
                        if viewModel?.isSubmitting == true { ProgressView() } else { Text("Post") }
                    }
                    .disabled(!(viewModel?.isValid ?? false) || viewModel?.isSubmitting == true)
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = CreatePostViewModel(
                    postService: environment.postService,
                    locationProvider: environment.locationProvider
                )
            }
        }
        .onChange(of: viewModel?.didSubmit) { _, didSubmit in
            if didSubmit == true {
                environment.feedRefreshSignal.bump()
                dismiss()
            }
        }
        // Composing a post is the most expensive thing in the app — up to six photos, each
        // picked and cropped by hand. Cancel and a downward swipe both threw all of it away
        // without asking, which is the situation the Log Out confirmation already covers
        // for a far cheaper action. The swipe is blocked rather than confirmed because a
        // sheet dismissal has no point at which to interpose a dialog.
        .interactiveDismissDisabled(hasUnsavedWork)
        .confirmationDialog(
            "Discard this post?",
            isPresented: $showingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
    }
}

private struct CreatePostForm: View {
    @Bindable var viewModel: CreatePostViewModel

    var body: some View {
        Form {
            Section {
                SquarePhotoAttachmentPicker(images: $viewModel.selectedImages, maxCount: 6) {
                    BumpLabel("Add photos", glyph: .photos, size: BumpIconSize.small)
                        .foregroundStyle(BumpColor.brand)
                        .frame(minHeight: BumpHitTarget.min)
                }
                if !viewModel.selectedImages.isEmpty {
                    attachmentStrip
                        .listRowInsets(EdgeInsets())
                }
            } header: {
                Text("Photos").bumpSectionLabel()
            } footer: {
                Text("Up to 6, cropped square.")
            }

            Section {
                if let picked = viewModel.picked {
                    PickedPlaceRow(place: picked) { viewModel.clearPick() }
                } else {
                    TextField("Shop name", text: $viewModel.shopQuery)
                        .onChange(of: viewModel.shopQuery) { _, newValue in viewModel.search(name: newValue) }

                    if viewModel.isSearching {
                        HStack(spacing: BumpSpacing.s) {
                            ProgressView()
                            Text("Searching Apple Maps…")
                                .font(BumpFont.caption)
                                .foregroundStyle(BumpColor.textSecondary)
                        }
                        .frame(minHeight: BumpHitTarget.min)
                    }

                    ForEach(viewModel.matches) { match in
                        Button {
                            viewModel.pick(match)
                        } label: {
                            PlaceSuggestionRow(name: match.name, detail: match.address, glyph: .storefront)
                        }
                        .accessibilityHint(String(localized: "Picks this place for your post"))
                    }

                    // The only dead end on this screen, so it says so plainly. A shop
                    // Apple Maps has no record of cannot be posted about at all: the
                    // server resolves every shop from Apple and rejects what it cannot
                    // find, so there is no typing past this.
                    if viewModel.didSearch && viewModel.matches.isEmpty {
                        FieldHint(
                            text: "No places found. Try the name as it appears on Apple Maps — only places Apple knows can be reviewed.",
                            tone: .error
                        )
                    }
                }
            } header: {
                Text("The place").bumpSectionLabel()
            } footer: {
                if !viewModel.isPlacePicked {
                    Text("Type the shop's name, then pick the right one from the list.")
                }
            }

            Section {
                RatingPickerView(rating: $viewModel.rating)
                    .padding(.vertical, BumpSpacing.xs)
            } header: {
                Text("Your rating").bumpSectionLabel()
            }

            Section {
                TextField("What made this place worth the trip?", text: $viewModel.caption, axis: .vertical)
                    .lineLimit(3...8)
                // Same counter the edit sheets already show, so the ceiling appears
                // while typing rather than as a 400 after every photo has uploaded.
                if let remaining = FreeTextRule.remaining(viewModel.caption) {
                    FieldHint(
                        text: "\(remaining) characters left",
                        tone: remaining < 0 ? .error : .neutral
                    )
                }
            } header: {
                Text("Caption").bumpSectionLabel()
            }

            if let errorMessage = viewModel.errorMessage {
                InlineErrorBanner(message: errorMessage)
                    .listRowBackground(Color.clear)
            }
        }
        .listRowBackground(BumpColor.surfaceSecondary)
        .bumpScrollBackground()
        .tint(BumpColor.brand)
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: BumpSpacing.s) {
                ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, data in
                    if let uiImage = UIImage(data: data) {
                        AttachmentThumbnail(image: uiImage, size: 72) {
                            viewModel.selectedImages.remove(at: index)
                        }
                    }
                }
            }
            .padding(BumpSpacing.m)
        }
        .scrollIndicators(.hidden)
    }
}

/// The place once it has been picked, in place of the search field.
///
/// The name and address are read-only because they are Apple's copy, not the user's: the
/// server resolves them from the identifier and never reads anything sent alongside it,
/// so an editable field here would change nothing that gets posted. "Change" goes back to
/// the list rather than to a blank field — the shop was picked out of a set of branches
/// and picking the neighbouring one should not mean retyping the name.
private struct PickedPlaceRow: View {
    let place: PlaceMatch
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.xs) {
            HStack(spacing: BumpSpacing.s) {
                BumpIcon(.seal, .filled, size: BumpIconSize.small)
                    .foregroundStyle(BumpColor.success)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                    Text(place.name)
                        .font(BumpFont.control)
                        .foregroundStyle(BumpColor.textPrimary)
                    Text(place.address)
                        .font(BumpFont.caption)
                        .foregroundStyle(BumpColor.textSecondary)
                }
                Spacer(minLength: 0)
                Button("Change", action: onChange)
                    .buttonStyle(.bumpText)
            }
            .frame(minHeight: BumpHitTarget.min)
            FieldHint(text: "Confirmed on Apple Maps. Directions open this exact place.")
        }
    }
}

private struct PlaceSuggestionRow: View {
    let name: String
    let detail: String
    let glyph: BumpGlyph

    var body: some View {
        HStack(spacing: BumpSpacing.s) {
            BumpIcon(glyph, size: BumpIconSize.small)
                .foregroundStyle(BumpColor.brand)
            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                Text(name)
                    .font(BumpFont.control)
                    .foregroundStyle(BumpColor.textPrimary)
                Text(detail)
                    .font(BumpFont.caption)
                    .foregroundStyle(BumpColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: BumpHitTarget.min)
        .contentShape(Rectangle())
    }
}
