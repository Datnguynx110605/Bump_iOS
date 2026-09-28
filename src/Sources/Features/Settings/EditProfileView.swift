import SwiftUI
import PhotosUI
import UIKit

struct EditProfileView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var account: AccountSummaryDto?
    @State private var name = ""
    @State private var bio = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var croppingImage: UIImage?
    @State private var showingCrop = false
    @State private var showingRemovePhotoConfirm = false

    private var isNameValid: Bool { AccountNameRule.isValid(name) }
    private var canSave: Bool { isNameValid && FreeTextRule.isValid(bio) && !isSaving && !isLoading }

    var body: some View {
        Form {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            ZStack {
                                AvatarView(url: account?.avatar?.url, size: 88)
                                if isUploadingAvatar {
                                    BumpColor.overlayChrome.clipShape(Circle()).frame(width: 88, height: 88)
                                    ProgressView().tint(.white)
                                }
                            }
                            .overlay(alignment: .bottomTrailing) {
                                BumpIcon(.camera, .circledFilled, size: BumpIconSize.large)
                                    .font(BumpFont.title)
                                    .foregroundStyle(.white, BumpColor.brandFill)
                            }
                        }
                        .accessibilityLabel(String(localized: "Change profile photo"))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    if account?.avatar != nil {
                        Button("Remove photo", role: .destructive) {
                            showingRemovePhotoConfirm = true
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(isUploadingAvatar)
                        .listRowBackground(Color.clear)
                    }
                }

                Section {
                    TextField("username", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: name) { _, newValue in name = AccountNameRule.sanitize(newValue) }
                    FieldHint(
                        text: name.isEmpty ? "Lowercase letters and numbers only." : "Looks good.",
                        tone: name.isEmpty ? .neutral : .success)
                } header: {
                    Text("Username").bumpSectionLabel()
                }

                Section {
                    TextField("Tell people about yourself", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                    // Same 2000-character ceiling and same counter as the sign-up bio and
                    // the caption fields. Without it an over-length bio stayed saveable
                    // and came back a 400 after the round trip.
                    if let remaining = FreeTextRule.remaining(bio) {
                        FieldHint(
                            text: "\(remaining) characters left",
                            tone: remaining < 0 ? .error : .neutral
                        )
                    }
                } header: {
                    Text("Bio").bumpSectionLabel()
                }

                if let errorMessage {
                    InlineErrorBanner(message: errorMessage)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listRowBackground(BumpColor.surfaceSecondary)
        .bumpScrollBackground()
        .tint(BumpColor.brand)
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving { ProgressView() } else { Text("Save") }
                }
                .disabled(!canSave)
            }
        }
        .task { await load() }
        .onChange(of: photoPickerItem) { _, newValue in
            Task { await loadForCropping(newValue) }
        }
        .confirmationDialog(
            "Remove your profile photo?",
            isPresented: $showingRemovePhotoConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove photo", role: .destructive) {
                Task { await removeAvatar() }
            }
        }
        .fullScreenCover(isPresented: $showingCrop) {
            if let croppingImage {
                SquareCropView(
                    image: croppingImage,
                    onConfirm: { data in
                        showingCrop = false
                        Task { await uploadAvatar(data) }
                    },
                    onCancel: { showingCrop = false }
                )
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let me = try await environment.accountService.me()
            account = me
            name = me.name.value
            bio = me.bio ?? ""
        } catch {
            errorMessage = APIError.userMessage(for: error)
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let account, name != account.name.value {
                try await environment.accountService.changeName(name)
            }
            if let account, bio != (account.bio ?? "") {
                try await environment.accountService.changeBio(bio.isEmpty ? nil : bio)
            }
            let updated = try await environment.accountService.me()
            environment.accountCache.store(updated)
            environment.feedRefreshSignal.bump()
            dismiss()
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't save your changes."))
        }
    }

    private func removeAvatar() async {
        isUploadingAvatar = true
        errorMessage = nil
        defer { isUploadingAvatar = false }
        do {
            try await environment.accountService.removeAvatar()
            let updated = try await environment.accountService.me()
            account = updated
            environment.accountCache.store(updated)
            environment.feedRefreshSignal.bump()
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't remove your photo."))
        }
    }

    private func loadForCropping(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        defer { photoPickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        croppingImage = image.normalizedOrientation()
        showingCrop = true
    }

    private func uploadAvatar(_ data: Data) async {
        isUploadingAvatar = true
        errorMessage = nil
        defer { isUploadingAvatar = false }
        do {
            try await environment.accountService.changeAvatar(ImageUpload(filename: "avatar.jpg", mimeType: "image/jpeg", data: data))
            let updated = try await environment.accountService.me()
            account = updated
            environment.accountCache.store(updated)
            environment.feedRefreshSignal.bump()
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't update your photo."))
        }
    }
}
