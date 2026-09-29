import Foundation

@MainActor
@Observable
final class CreatePostViewModel {
    /// The shop name as typed. Only ever a search term — it is never sent anywhere, and
    /// what gets posted is the identifier of whichever match the user picks.
    var shopQuery = ""
    var caption = ""
    var rating = 5
    var selectedImages: [Data] = []

    private(set) var matches: [PlaceMatch] = []
    private(set) var isSearching = false
    /// Whether a search has completed for the current query. Distinguishes "nothing typed
    /// yet" from "Apple Maps knows no such place", which are the same empty list but need
    /// different words — the second one is a dead end the user has to be told about.
    private(set) var didSearch = false

    /// The picked place, and the entire shop half of the request.
    ///
    /// A post carries a place identifier and nothing else: the server resolves the name,
    /// address and coordinate from Apple itself and accepts none of them from the client.
    /// So there is no typed-shop path any more — a place Apple cannot answer for is one
    /// the server rejects, and a post cannot be made about it at all.
    private(set) var picked: PlaceMatch?

    var isPlacePicked: Bool { picked != nil }

    var isSubmitting = false
    var errorMessage: String?
    var didSubmit = false

    private var searchTask: Task<Void, Never>?

    private let postService: PostService
    private let locationProvider: LocationProvider

    init(postService: PostService, locationProvider: LocationProvider) {
        self.postService = postService
        self.locationProvider = locationProvider
    }

    /// Debounced so a search does not fire on every keystroke of a shop name.
    func search(name: String) {
        searchTask?.cancel()
        didSearch = false

        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            matches = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            isSearching = true
            defer { isSearching = false }
            // `lastKnown` rather than `requestCurrent()`: the bias is a nicety, and asking
            // for location here would raise a permission prompt on the compose screen,
            // long after the screen that explains why location is wanted. Whoever has
            // already used the nearby shops section gets the better-ordered list; nobody
            // gets a prompt for it.
            let found = await PlaceLookup.search(name: name, near: locationProvider.lastKnown)
            guard !Task.isCancelled else { return }
            matches = found
            didSearch = true
        }
    }

    /// Picking is what makes the post postable. The matches are deliberately kept so that
    /// "Change" drops straight back into the list the user was choosing from rather than
    /// making them type the name again.
    func pick(_ match: PlaceMatch) {
        picked = match
        searchTask?.cancel()
        isSearching = false
    }

    func clearPick() {
        picked = nil
    }

    /// Whether closing the sheet would throw away work. Cropped photos are the expensive
    /// part — each one cost the user a pick, a pinch and a confirm — so the check leads
    /// with them, but a picked shop or a caption is worth just as much a confirmation.
    var hasUnsavedWork: Bool {
        isPlacePicked
            || !selectedImages.isEmpty
            || !shopQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The rules of `CreatePostValidator` that a person can actually break. Checked here
    /// because `submit()` uploads every attached photo before the command is validated,
    /// so a caption two characters over the limit used to cost a full multi-megabyte
    /// upload and come back as a 400. Its length cap on `placeId` is left out: the
    /// identifier comes from MapKit, not from anything typed.
    var isValid: Bool {
        isPlacePicked && FreeTextRule.isValid(caption) && (1...5).contains(rating)
    }

    func submit() async {
        guard let picked, isValid else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let uploads = selectedImages.map { ImageUpload(filename: "photo.jpg", mimeType: "image/jpeg", data: $0) }
            _ = try await postService.create(
                placeId: picked.placeId,
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
