import Contacts
import CoreLocation
import Foundation
import MapKit
import Observation

/// A latitude/longitude pair, always carried as a unit.
///
/// `GET /Shop/around` takes two non-optional query parameters and `GET /Post/related`
/// ignores a half-supplied pair, so both call sites need the pair to be present or absent
/// together rather than two independent optionals.
struct PostCoordinate: Equatable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

/// Wraps `CLLocationManager` in an async, observable form.
///
/// Location is optional everywhere it is used: the compose screen only biases its place
/// search with it, the feed loses its nearby tier without it, and the nearby-shops
/// section degrades to an explicit "location off" state rather than an empty list —
/// `GET /Shop/around` cannot be called at all without a coordinate, so an empty result
/// and a missing permission are different things and must look different.
@MainActor
@Observable
final class LocationProvider {
    /// `requestLocation()` is not guaranteed to call back at all — with location services
    /// disabled system-wide, or a cold GPS that never gets a fix, neither the success nor
    /// the failure delegate method fires. Every wait is therefore bounded, or a caller
    /// would await forever and leave its UI on a spinner with no way out.
    private static let fixTimeout: Duration = .seconds(10)
    /// The permission prompt is answered by a human and can legitimately sit for a while,
    /// so it gets a far longer bound than a GPS fix.
    private static let promptTimeout: Duration = .seconds(60)

    private(set) var authorizationStatus: CLAuthorizationStatus
    /// The last coordinate resolved this session. Reused by the nearby section so
    /// revisiting the tab doesn't re-trigger a fix.
    private(set) var lastKnown: PostCoordinate?

    private let manager = CLLocationManager()
    private let delegate = Delegate()

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var canRequest: Bool {
        authorizationStatus == .notDetermined
    }

    init() {
        authorizationStatus = manager.authorizationStatus
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.delegate = delegate
        delegate.onAuthorizationChange = { [weak self] status in
            self?.authorizationStatus = status
        }
    }

    /// Resolves a coordinate, requesting permission first if it has never been asked.
    /// Returns nil when permission is unavailable, the prompt goes unanswered, or no fix
    /// arrives in time — callers branch on the optional and read `authorizationStatus`
    /// when they need to say *why* it failed.
    func requestCurrent() async -> PostCoordinate? {
        if authorizationStatus == .notDetermined {
            let status = await withCheckedContinuation { continuation in
                delegate.awaitAuthorization(continuation, timeout: Self.promptTimeout, fallback: manager.authorizationStatus)
                manager.requestWhenInUseAuthorization()
            }
            authorizationStatus = status
        }

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return nil
        }

        let coordinate = await withCheckedContinuation { continuation in
            delegate.awaitLocation(continuation, timeout: Self.fixTimeout)
            manager.requestLocation()
        }
        if let coordinate { lastKnown = coordinate }
        return coordinate
    }
}

/// `CLLocationManagerDelegate` needs an `NSObject`. Every pending continuation is cleared
/// before it is resumed and resumed exactly once: resuming a checked continuation twice
/// traps, and `requestLocation` can report a location, a failure, both, or neither.
///
/// Callbacks arrive on the queue the manager was created on — the main queue here, which
/// is also where `LocationProvider` calls in from, so the pending slots are only ever
/// touched from the main actor.
@MainActor
private final class Delegate: NSObject, CLLocationManagerDelegate {
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<PostCoordinate?, Never>?

    func awaitAuthorization(
        _ continuation: CheckedContinuation<CLAuthorizationStatus, Never>,
        timeout: Duration,
        fallback: CLAuthorizationStatus
    ) {
        // An overlapping request must not strand the previous waiter: it is settled with
        // the status as it stands before the slot is reused.
        finishAuthorization(fallback)
        authorizationContinuation = continuation
        Task { [weak self] in
            try? await Task.sleep(for: timeout)
            self?.finishAuthorization(fallback)
        }
    }

    func awaitLocation(_ continuation: CheckedContinuation<PostCoordinate?, Never>, timeout: Duration) {
        finishLocation(nil)
        locationContinuation = continuation
        Task { [weak self] in
            try? await Task.sleep(for: timeout)
            self?.finishLocation(nil)
        }
    }

    private func finishAuthorization(_ status: CLAuthorizationStatus) {
        guard let continuation = authorizationContinuation else { return }
        authorizationContinuation = nil
        continuation.resume(returning: status)
    }

    private func finishLocation(_ coordinate: PostCoordinate?) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(returning: coordinate)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            onAuthorizationChange?(status)
            // Fires once on delegate assignment with the current status; only a resolved
            // answer should complete a pending permission prompt.
            guard status != .notDetermined else { return }
            finishAuthorization(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last.map { PostCoordinate($0.coordinate) }
        MainActor.assumeIsolated { finishLocation(coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { finishLocation(nil) }
    }
}

/// A place on Apple Maps that a post can be written about.
///
/// `placeId` is Apple's own identifier and the only thing the server accepts about a
/// shop: it resolves the name, address and coordinate from Apple itself, so the two
/// strings here exist purely so a human can tell two branches apart before picking one.
/// A place Apple has no identifier for is not representable, because it could not be
/// posted about — see `PlaceLookup.search(name:near:)`.
struct PlaceMatch: Identifiable, Equatable {
    var id: String { placeId }
    let placeId: String
    let name: String
    let address: String
}

/// Finds the shop the user is about to review, by name.
///
/// This is the whole of shop entry now. Nothing is typed through to the server any more —
/// a post carries an identifier and the server resolves the place from Apple — so the job
/// here is to turn a name into a short list of real places precise enough to pick the
/// right branch out of.
@MainActor
enum PlaceLookup {
    /// A common name answers with dozens of branches; nobody scrolls a form section that
    /// long, and MapKit returns them best-first, so the tail is the wrong part anyway.
    private static let maxMatches = 10
    /// Wide enough to cover a city and the towns around it, so a shop a short drive away
    /// still appears, and narrow enough that the local branch outranks the one abroad.
    private static let searchSpan: CLLocationDistance = 50_000

    /// Places matching `name`, biased toward `coordinate` when one is known.
    ///
    /// The bias is what disambiguates a chain: "Blue Bottle" alone is a worldwide list,
    /// and the same query around a known point puts the branches the user could actually
    /// be standing in at the top. It is only a bias — a shop outside the region still
    /// comes back, which matters for reviewing somewhere remembered from a trip.
    static func search(name: String, near coordinate: PostCoordinate?) async -> [PlaceMatch] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        // Businesses, not street addresses: a post reviews a shop, and an address result
        // carries no place identifier to post with.
        request.resultTypes = .pointOfInterest
        if let coordinate {
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
                latitudinalMeters: searchSpan,
                longitudinalMeters: searchSpan
            )
        }

        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }

        // Dropped rather than shown greyed out: a place with no identifier, no name or no
        // address is one the server would reject or the user could not tell apart, and a
        // row that looks pickable and then fails the Post button is worse than absent.
        let matches = response.mapItems.compactMap { item -> PlaceMatch? in
            guard let placeId = item.identifier?.rawValue,
                  let name = item.name,
                  let address = formatted(item.placemark) else { return nil }
            return PlaceMatch(placeId: placeId, name: name, address: address)
        }
        return Array(matches.prefix(maxMatches))
    }

    /// `CNPostalAddressFormatter` writes a mailing label, so the line breaks are flattened
    /// into the single line the picker row shows.
    private static func formatted(_ placemark: CLPlacemark) -> String? {
        guard let postalAddress = placemark.postalAddress else { return nil }
        let address = CNPostalAddressFormatter()
            .string(from: postalAddress)
            .split(separator: "\n")
            .joined(separator: ", ")
        return address.isEmpty ? nil : address
    }
}
