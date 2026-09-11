import Foundation

@MainActor
@Observable
final class CreatePostViewModel {
    var shopName = ""
    var shopAddress = ""
    var caption = ""
    var rating = 5
    var selectedImages: [Data] = []

    /// Only ever set as a pair, and only meaningful for a shop nobody has posted yet:
    /// the server reuses an existing (name, address) row and never overwrites its
    /// coordinate, so this is what puts a brand-new shop on the nearby map.
    private(set) var coordinate: PostCoordinate?
    private(set) var isLocating = false
    /// Places MapKit knows about at the attached pin, offered so the shop name and
    /// address can be tapped in rather than typed.
    private(set) var nearbyPlaces: [NearbyPlace] = []
    private(set) var locationIssue: LocationIssue?

    /// Attaching a location fails in three ways that need three different sentences: no
    /// permission, permission but no fix, and a fix over a place MapKit cannot name.
    /// Collapsing them leaves the user staring at a button that did nothing.
    enum LocationIssue: Equatable {
        case denied
        case noFix
        case noPlaces
    }

    var shopSuggestions: [ShopSummaryDto] = []
    var isSearchingShops = false
    private var shopSearchTask: Task<Void, Never>?
    private var pickedShopName: String?

    var isSubmitting = false
    var errorMessage: String?
    var didSubmit = false

    private let postService: PostService
    private let shopService: ShopService
    private let locationProvider: LocationProvider

    init(postService: PostService, shopService: ShopService, locationProvider: LocationProvider) {
        self.postService = postService
        self.shopService = shopService
        self.locationProvider = locationProvider
    }

    func attachLocation() async {
        isLocating = true
        locationIssue = nil
        defer { isLocating = false }
        guard let fix = await locationProvider.requestCurrent() else {
            locationIssue = locationProvider.isDenied ? .denied : .noFix
            return
        }
        nearbyPlaces = await PlaceLookup.places(around: fix)
        // Typed text wins: the button is there to save typing, not to undo it. The field
        // is read after the lookup, not before, so text typed while it was in flight is
        // still respected.
        let resolvedAddress = await PlaceLookup.address(of: fix)
        if shopAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let resolvedAddress {
            shopAddress = resolvedAddress
        }
        // Set last: the row swaps to "Location attached" the moment this lands, and it
        // should not do that while the place list it is about to show is still loading.
        coordinate = fix
        if nearbyPlaces.isEmpty { locationIssue = .noPlaces }
    }

    func clearLocation() {
        coordinate = nil
        nearbyPlaces = []
        locationIssue = nil
    }

    /// A place picked off the map fills both fields and moves the pin onto the shop
    /// itself rather than wherever the phone happened to be standing — the server fixes a
    /// new shop's coordinate on the first post and never revises it.
    ///
    /// The name change re-runs the shop search, so if Bump already has this shop its own
    /// row appears underneath; picking that one keeps the exact strings the server matches
    /// on instead of creating a second row for the same place.
    func selectPlace(_ place: NearbyPlace) {
        shopName = place.name
        shopAddress = place.address
        coordinate = place.coordinate
        nearbyPlaces = []
        locationIssue = nil
    }

    /// Mirrors `CreatePostValidator` on the server. Checked here because `submit()`
    /// uploads every attached photo before the command is validated, so a caption two
    /// characters over the limit used to cost a full multi-megabyte upload and come back
    /// as a 400.
    var isValid: Bool {
        ShopFieldRule.isValid(shopName)
            && ShopFieldRule.isValid(shopAddress)
            && FreeTextRule.isValid(caption)
            && (1...5).contains(rating)
    }

    func searchShops(keyword: String) {
        shopSearchTask?.cancel()
        // Filling the field from a suggestion is itself a text change, so without this the
        // list the user just picked from reappears 300ms later, unpicked.
        // Single-shot: the programmatic set fires `onChange` once, and clearing here keeps
        // a later retype of the same name from being silently unsearchable.
        guard keyword != pickedShopName else {
            pickedShopName = nil
            shopSuggestions = []
            return
        }
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
        pickedShopName = shop.name
        shopName = shop.name
        shopAddress = shop.address
        shopSuggestions = []
        nearbyPlaces = []
    }

    /// Attaching a location is optional, so a shop can be typed in full and posted with no
    /// pin — and a shop with no pin is invisible to the nearby search for good. Rather
    /// than require the button, resolve a coordinate here when none was attached.
    private func resolvedCoordinate(forAddress address: String) async -> PostCoordinate? {
        if let coordinate { return coordinate }

        if let geocoded = await PlaceLookup.coordinate(of: address) {
            return geocoded
        }

        // A vague or misspelled address geocodes to nothing. The last fix the provider
        // saw is a worse pin than the shop's own address but a far better one than none,
        // which is permanent absence from the nearby list. Deliberately `lastKnown` and
        // not `requestCurrent()`: asking here would raise a permission prompt on the
        // Post button, long after the screen that explains why location is wanted.
        return locationProvider.lastKnown
    }

    func submit() async {
        guard isValid else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let uploads = selectedImages.map { ImageUpload(filename: "photo.jpg", mimeType: "image/jpeg", data: $0) }
            let trimmedAddress = shopAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await postService.create(
                shopName: shopName.trimmingCharacters(in: .whitespacesAndNewlines),
                shopAddress: trimmedAddress,
                coordinate: await resolvedCoordinate(forAddress: trimmedAddress),
                caption: caption.isEmpty ? nil : caption,
                rate: rating,
                images: uploads
            )
            didSubmit = true
            SoundEffect.sent.play()
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't share your post."))
        }
    }
}
