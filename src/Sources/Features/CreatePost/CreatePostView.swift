import SwiftUI
import PhotosUI
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
                PhotosPicker(selection: $viewModel.photoPickerItems, maxSelectionCount: 6, matching: .images) {
                    Label("Add Photos", systemImage: "photo.on.rectangle")
                }
                if !viewModel.selectedImages.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { _, data in
                                if let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: BumpRadius.control))
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .padding(BumpSpacing.s)
                }
            }

            Section("Shop") {
                TextField("Shop name", text: $viewModel.shopName)
                    .onChange(of: viewModel.shopName) { _, newValue in viewModel.searchShops(keyword: newValue) }
                if !viewModel.shopSuggestions.isEmpty {
                    ForEach(viewModel.shopSuggestions) { shop in
                        Button {
                            viewModel.selectShop(shop)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(shop.name).foregroundStyle(.primary)
                                Text(shop.address).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                TextField("Address", text: $viewModel.shopAddress)
            }

            Section("Your Rating") {
                RatingPickerView(rating: $viewModel.rating)
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
    }
}
