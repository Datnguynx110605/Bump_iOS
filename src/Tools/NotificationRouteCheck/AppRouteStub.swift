import Foundation

// Only the data half of the real AppRoute. The full type lives in
// Features/Root/AppRoute.swift alongside a SwiftUI View extension that pulls in every
// screen in the app, which is why it can't be compiled into a standalone check.
// NotificationModels.swift — the file actually under test — uses only these two cases.
enum AppRoute: Hashable {
    case post(UUID)
    case account(UUID)
    case shop(UUID)
    case followers(UUID)
    case following(UUID)
    case postReactors(UUID)
    case commentReactors(UUID)
    case saved
}
