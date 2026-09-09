import CoreLocation
import Foundation
import Observation

/// A latitude/longitude pair, always carried as a unit.
///
/// The server rejects a half-supplied coordinate on post creation, and
/// `GET /Shop/around` takes two non-optional query parameters, so both call sites need
/// the pair to be present or absent together rather than two independent optionals.
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
/// Location is optional everywhere it is used: a post can be shared without a place, and
/// the nearby-shops section degrades to an explicit "location off" state rather than an
/// empty list — `GET /Shop/around` cannot be called at all without a coordinate, so an
/// empty result and a missing permission are different things and must look different.
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
