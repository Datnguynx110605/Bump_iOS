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
                    shopService: environment.shopService,
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
                    Label("Add photos", systemImage: "photo.on.rectangle")
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
                TextField("Shop name", text: $viewModel.shopName)
                    .onChange(of: viewModel.shopName) { _, newValue in viewModel.searchShops(keyword: newValue) }
                if ShopFieldRule.isTooLong(viewModel.shopName) {
                    FieldHint(
                        text: "Shop name is too long (max \(ShopFieldRule.maxLength) characters).",
                        tone: .error
                    )
                }
                ForEach(viewModel.shopSuggestions) { shop in
                    Button {
                        viewModel.selectShop(shop)
                    } label: {
                        PlaceSuggestionRow(name: shop.name, detail: shop.address, icon: "mappin.circle")
                    }
                    .accessibilityHint(String(localized: "Fills in this shop"))
                }
                ForEach(viewModel.nearbyPlaces) { place in
                    Button {
                        viewModel.selectPlace(place)
                    } label: {
                        PlaceSuggestionRow(name: place.name, detail: place.address, icon: "storefront")
                    }
                    .accessibilityHint(String(localized: "Fills in this place"))
                }
                TextField("Address", text: $viewModel.shopAddress)
                if ShopFieldRule.isTooLong(viewModel.shopAddress) {
                    FieldHint(
                        text: "Address is too long (max \(ShopFieldRule.maxLength) characters).",
                        tone: .error
                    )
                }
                LocationAttachRow(viewModel: viewModel)
            } header: {
                Text("The place").bumpSectionLabel()
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

/// One tappable place, whether it came from Bump's own shop list or from the map.
private struct PlaceSuggestionRow: View {
    let name: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(spacing: BumpSpacing.s) {
            Image(systemName: icon)
                .foregroundStyle(BumpColor.brand)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: BumpSpacing.xs) {
                Text(name)
                    .font(BumpFont.control)
                    .foregroundStyle(BumpColor.textPrimary)
                Text(detail)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(BumpColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: BumpHitTarget.min)
        .contentShape(Rectangle())
    }
}

/// Fills the shop fields from where the user is standing, and pins the post while it is
/// at it. The pin is what lets a brand-new shop appear in the nearby list, but naming the
/// place is the part the user actually feels, so the copy leads with that.
private struct LocationAttachRow: View {
    let viewModel: CreatePostViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BumpSpacing.xs) {
            if viewModel.coordinate != nil {
                HStack(spacing: BumpSpacing.s) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(BumpColor.success)
                        .accessibilityHidden(true)
                    Text("Location attached")
                        .font(BumpFont.callout)
                        .foregroundStyle(BumpColor.textPrimary)
                    Spacer(minLength: 0)
                    Button("Remove") { viewModel.clearLocation() }
                        .buttonStyle(.bumpText)
                }
                .frame(minHeight: BumpHitTarget.min)
                if viewModel.locationIssue == .noPlaces {
                    FieldHint(text: "No places found here. Type the shop name yourself.")
                }
            } else {
                Button {
                    Task { await viewModel.attachLocation() }
                } label: {
                    HStack(spacing: BumpSpacing.s) {
                        if viewModel.isLocating {
                            ProgressView()
                        } else {
                            Image(systemName: "location.circle")
                                .foregroundStyle(BumpColor.brand)
                                .accessibilityHidden(true)
                        }
                        Text("Use my current location")
                            .foregroundStyle(BumpColor.brand)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: BumpHitTarget.min)
                    .contentShape(Rectangle())
                }
                .disabled(viewModel.isLocating)

                switch viewModel.locationIssue {
                case .denied:
                    FieldHint(text: "Location is off. Turn it on in Settings to pin this shop.", tone: .error)
                case .noFix:
                    FieldHint(text: "Couldn't get your location. Try again.", tone: .error)
                default:
                    FieldHint(text: "Optional. Fills in nearby shops and pins this one for nearby searches.")
                }
            }
        }
    }
}
