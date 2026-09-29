import Foundation

// The data half of the real PlaceMatch. The full type lives in
// Sources/Core/Utilities/LocationProvider.swift, which cannot be compiled into a
// standalone check that runs on the host: that file's LocationProvider reads
// CLAuthorizationStatus.authorizedWhenInUse, which is unavailable on macOS. PlaceMatch
// itself is a plain struct and is copied here field-for-field — if the real one gains a
// field the server cares about, this is the copy to update.
struct PlaceMatch: Identifiable, Equatable {
    var id: String { placeId }
    let placeId: String
    let name: String
    let address: String
}
