import MapKit
import UIKit

@MainActor
enum AppleMaps {
    /// Opens directions to a shop.
    ///
    /// With Apple's own identifier this opens the exact place Apple holds. Without one
    /// there is only a name and an address, and Maps has to go and search for them — which
    /// is how a pin lands on a different branch, on a similarly named shop, or on nothing
    /// at all. That search is the fallback, not the plan: shops the server verified carry
    /// an identifier, and shops somebody typed in do not.
    static func openDirections(placeId: String?, shopName: String, address: String) {
        guard let placeId, let identifier = MKMapItem.Identifier(rawValue: placeId) else {
            openByQuery(shopName: shopName, address: address)
            return
        }

        Task {
            // An identifier can stop resolving — Apple retires a place, or merges it into
            // another. The query is a worse answer than the place itself and a far better
            // one than a button that does nothing.
            guard let item = try? await MKMapItemRequest(mapItemIdentifier: identifier).mapItem else {
                openByQuery(shopName: shopName, address: address)
                return
            }

            item.openInMaps(
                launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault]
            )
        }
    }

    private static func openByQuery(shopName: String, address: String) {
        let query = "\(shopName), \(address)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://maps.apple.com/?q=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }
}
