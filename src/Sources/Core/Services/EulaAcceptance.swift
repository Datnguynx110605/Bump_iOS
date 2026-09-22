import SwiftUI

@Observable
final class EulaAcceptance {
    static let shared = EulaAcceptance()

    private static let storageKey = "eulaAccepted"

    var hasAccepted: Bool {
        didSet { UserDefaults.standard.set(hasAccepted, forKey: Self.storageKey) }
    }

    private init() {
        hasAccepted = UserDefaults.standard.bool(forKey: Self.storageKey)
    }
}
