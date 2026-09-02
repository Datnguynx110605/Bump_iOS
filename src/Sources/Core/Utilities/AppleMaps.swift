import UIKit

@MainActor
enum AppleMaps {
    static func openDirections(shopName: String, address: String) {
        let query = "\(shopName), \(address)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://maps.apple.com/?q=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }
}
