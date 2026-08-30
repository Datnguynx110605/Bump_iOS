import SwiftUI
import PhotosUI

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

    private var isNameValid: Bool { AccountNameRule.isValid(name) }

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
                                    Color.black.opacity(0.3).clipShape(Circle()).frame(width: 88, height: 88)
                                    ProgressView().tint(.white)
                                }
                            }
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(.title2))
                                    .foregroundStyle(.white, Color.accentColor)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Username") {
                    TextField("username", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: name) { _, newValue in name = AccountNameRule.sanitize(newValue) }
                    FieldHint(
                        text: name.isEmpty ? "Lowercase letters and numbers only." : "Looks good.",
                        tone: name.isEmpty ? .neutral : .success)
                }

                Section("Bio") {
                    TextField("Tell people about yourself", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    InlineErrorBanner(message: errorMessage)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving { ProgressView() } else { Text("Save") }
                }
                .disabled(!isNameValid || isSaving || isLoading)
            }
        }
        .task { await load() }
        .onChange(of: photoPickerItem) { _, newValue in
            Task { await uploadAvatar(newValue) }
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
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
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
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't save your changes."
        }
    }

    private func uploadAvatar(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isUploadingAvatar = true
        errorMessage = nil
        defer { isUploadingAvatar = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            try await environment.accountService.changeAvatar(ImageUpload(filename: "avatar.jpg", mimeType: "image/jpeg", data: data))
            let updated = try await environment.accountService.me()
            account = updated
            environment.accountCache.store(updated)
            environment.feedRefreshSignal.bump()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't update your photo."
        }
    }
}
