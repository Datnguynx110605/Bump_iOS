import Foundation

@MainActor
@Observable
final class CreatePostViewModel {
    var shopName = ""
    var shopAddress = ""
    var caption = ""
    var rating = 5
    var selectedImages: [Data] = []

    /// Apple's identifier for the picked place, and the only shop field the server
    /// trusts. While it is set, the name and address on this screen are Apple's copy for
    /// the user to read — the server resolves its own from the identifier and ignores
    /// anything sent alongside it — which is why the fields go read-only rather than
    /// staying editable and lying about what gets posted.
    private(set) var placeId: String?

    var isPlacePicked: Bool { placeId != nil }

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
        placeId = place.placeId
        nearbyPlaces = []
        shopSuggestions = []
        locationIssue = nil
    }

    /// Back to typing. The name and address go with the identifier because they were
    /// Apple's words, not the user's — leaving them behind would seed a hand-typed shop
    /// with text that describes a place the post is no longer about.
    func clearPickedPlace() {
        placeId = nil
        shopName = ""
        shopAddress = ""
        pickedShopName = nil
        coordinate = nil
        nearbyPlaces = []
        shopSuggestions = []
        locationIssue = nil
    }

    /// Whether closing the sheet would throw away work. Cropped photos are the expensive
    /// part — each one cost the user a pick, a pinch and a confirm — so the check leads
    /// with them, but a typed shop name or caption is worth just as much a confirmation.
    var hasUnsavedWork: Bool {
        isPlacePicked
            || !selectedImages.isEmpty
            || !shopName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !shopAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Mirrors `CreatePostValidator` on the server. Checked here because `submit()`
    /// uploads every attached photo before the command is validated, so a caption two
    /// characters over the limit used to cost a full multi-megabyte upload and come back
    /// as a 400.
    var isValid: Bool {
        (isPlacePicked || (ShopFieldRule.isValid(shopName) && ShopFieldRule.isValid(shopAddress)))
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

    /// Picking a shop Bump already holds carries its identifier forward when it has one,
    /// so posting about a verified shop stays verified instead of quietly re-creating it
    /// from its own strings.
    func selectShop(_ shop: ShopSummaryDto) {
        pickedShopName = shop.name
        shopName = shop.name
        shopAddress = shop.address
        placeId = shop.placeId
        shopSuggestions = []
        nearbyPlaces = []
    }

    /// Attaching a location is optional, so a shop can be typed in full and posted with no
    /// pin — and a shop with no pin is invisible to the nearby search for good. Rather
    /// than require the button, resolve a coordinate here when none was attached.
    ///
    /// Never called for a picked place: that coordinate is Apple's own, and geocoding the
    /// address a second time or falling back to where the phone is standing could only
    /// make it worse.
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
            let trimmedName = shopName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedAddress = shopAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            // A picked place is described entirely by its identifier. The server resolves
            // the name, address and coordinate from Apple and does not read the ones sent
            // with them, so sending this screen's copies would be noise at best and a
            // disagreement with what actually gets stored at worst.
            let isTyped = placeId == nil
            var coordinate: PostCoordinate?
            if isTyped {
                coordinate = await resolvedCoordinate(forAddress: trimmedAddress)
            }
            _ = try await postService.create(
                placeId: placeId,
                shopName: isTyped ? trimmedName : nil,
                shopAddress: isTyped ? trimmedAddress : nil,
                coordinate: coordinate,
                caption: caption.isEmpty ? nil : caption,
                rate: rating,
                images: uploads
            )
            didSubmit = true
            SoundEffect.sent.play()
            HapticFeedback.succeeded()
        } catch {
            errorMessage = APIError.userMessage(for: error, fallback: String(localized: "Couldn't share your post."))
        }
    }
}
