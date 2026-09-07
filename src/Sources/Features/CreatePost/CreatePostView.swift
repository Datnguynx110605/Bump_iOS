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
                viewModel = CreatePostViewModel(postService: environment.postService, shopService: environment.shopService)
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
                        .foregroundStyle(Color.accentColor)
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
                        HStack(spacing: BumpSpacing.s) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(shop.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(BumpColor.textPrimary)
                                Text(shop.address)
                                    .font(.caption)
                                    .foregroundStyle(BumpColor.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: BumpHitTarget.min)
                        .contentShape(Rectangle())
                    }
                    .accessibilityHint(String(localized: "Fills in this shop"))
                }
                TextField("Address", text: $viewModel.shopAddress)
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
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: BumpRadius.small, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    viewModel.selectedImages.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.body)
                                        .foregroundStyle(.white, .black.opacity(0.55))
                                        .padding(3)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String(localized: "Remove photo"))
                            }
                    }
                }
            }
            .padding(BumpSpacing.m)
        }
        .scrollIndicators(.hidden)
    }
}
