import SwiftUI
import UIKit

struct CreatePostView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreatePostViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    CreatePostForm(viewModel: viewModel)
                } else {
                    LoadingView()
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await viewModel?.submit() }
                    } label: {
                        if viewModel?.isSubmitting == true { ProgressView() } else { Text("Share") }
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
    }
}

private struct CreatePostForm: View {
    @Bindable var viewModel: CreatePostViewModel

    var body: some View {
        Form {
            Section {
                SquarePhotoAttachmentPicker(images: $viewModel.selectedImages, maxCount: 6) {
                    Label("Add Photos", systemImage: "photo.on.rectangle")
                        .foregroundStyle(BumpColor.brand)
                        .frame(minHeight: BumpHitTarget.min)
                }
                if !viewModel.selectedImages.isEmpty {
                    attachmentStrip
                        .listRowInsets(EdgeInsets())
                }
            } header: {
                Text("Photos")
            } footer: {
                Text("Up to 6 photos, squared to a 1:1 crop.")
            }

            Section("Shop") {
                TextField("Shop name", text: $viewModel.shopName)
                    .onChange(of: viewModel.shopName) { _, newValue in viewModel.searchShops(keyword: newValue) }
                ForEach(viewModel.shopSuggestions) { shop in
                    Button {
                        viewModel.selectShop(shop)
                    } label: {
                        PlaceSuggestionRow(name: shop.name, detail: shop.address, icon: "mappin.circle.fill")
                    }
                    .accessibilityHint(String(localized: "Fills in this shop"))
                }
                ForEach(viewModel.nearbyPlaces) { place in
                    Button {
                        viewModel.selectPlace(place)
                    } label: {
                        PlaceSuggestionRow(name: place.name, detail: place.address, icon: "storefront.fill")
                    }
                    .accessibilityHint(String(localized: "Fills in this place"))
                }
                TextField("Address", text: $viewModel.shopAddress)
                LocationAttachRow(viewModel: viewModel)
            }

            Section("Your Rating") {
                RatingPickerView(rating: $viewModel.rating)
                    .padding(.vertical, BumpSpacing.xs)
            }

            Section("Caption") {
                TextField("What made this place worth a Bump?", text: $viewModel.caption, axis: .vertical)
                    .lineLimit(3...8)
            }

            if let errorMessage = viewModel.errorMessage {
                InlineErrorBanner(message: errorMessage)
                    .listRowBackground(Color.clear)
            }
        }
        .bumpScrollBackground()
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
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BumpColor.textPrimary)
                Text(detail)
                    .font(.caption)
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
                        .font(.subheadline)
                        .foregroundStyle(BumpColor.textPrimary)
                    Spacer(minLength: 0)
                    Button("Remove") { viewModel.clearLocation() }
                        .buttonStyle(.bumpText)
                }
                .frame(minHeight: BumpHitTarget.min)
                if viewModel.locationIssue == .noPlaces {
                    FieldHint(text: String(localized: "No places found here. Type the shop name yourself."))
                }
            } else {
                Button {
                    Task { await viewModel.attachLocation() }
                } label: {
                    HStack(spacing: BumpSpacing.s) {
                        if viewModel.isLocating {
                            ProgressView()
                        } else {
                            Image(systemName: "location.circle.fill")
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
                    FieldHint(text: String(localized: "Location is off. Turn it on in Settings to pin this shop."), tone: .error)
                case .noFix:
                    FieldHint(text: String(localized: "Couldn't get your location. Try again."), tone: .error)
                default:
                    FieldHint(text: String(localized: "Optional. Fills in nearby shops and pins this one for nearby searches."))
                }
            }
        }
    }
}
