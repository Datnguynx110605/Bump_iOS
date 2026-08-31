import Foundation

@MainActor
@Observable
final class CreatePostViewModel {
    var shopName = ""
    var shopAddress = ""
    var caption = ""
    var rating = 5
    var selectedImages: [Data] = []

    var shopSuggestions: [ShopSummaryDto] = []
    var isSearchingShops = false
    private var shopSearchTask: Task<Void, Never>?

    var isSubmitting = false
    var errorMessage: String?
    var didSubmit = false

    private let postService: PostService
    private let shopService: ShopService

    init(postService: PostService, shopService: ShopService) {
        self.postService = postService
        self.shopService = shopService
    }

    var isValid: Bool {
        !shopName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !shopAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && rating >= 0
    }

    func searchShops(keyword: String) {
        shopSearchTask?.cancel()
        guard !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            shopSuggestions = []
            return
        }
        shopSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            isSearchingShops = true
            defer { isSearchingShops = false }
            do {
                let page = try await shopService.search(keyword: keyword, cursor: nil, pageSize: 8)
                guard !Task.isCancelled else { return }
                shopSuggestions = page.items
            } catch {
                shopSuggestions = []
            }
        }
    }

    func selectShop(_ shop: ShopSummaryDto) {
        shopName = shop.name
        shopAddress = shop.address
        shopSuggestions = []
    }

    func submit() async {
        guard isValid else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let uploads = selectedImages.map { ImageUpload(filename: "photo.jpg", mimeType: "image/jpeg", data: $0) }
            _ = try await postService.create(
                shopName: shopName.trimmingCharacters(in: .whitespacesAndNewlines),
                shopAddress: shopAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                caption: caption.isEmpty ? nil : caption,
                rate: rating,
                images: uploads
            )
            didSubmit = true
            SoundEffect.confirm.play()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(localized: "Couldn't share your post.")
        }
    }
}
