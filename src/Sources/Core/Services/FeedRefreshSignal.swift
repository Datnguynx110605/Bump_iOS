import Foundation

@MainActor
@Observable
final class FeedRefreshSignal {
    private(set) var version = 0

    func bump() {
        version += 1
    }
}
