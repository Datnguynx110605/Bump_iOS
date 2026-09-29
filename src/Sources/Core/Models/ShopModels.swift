import Foundation

struct ShopDto: Decodable, Identifiable {
    let id: UUID
    let name: String
    let address: String
    let rate: Wrapped<Int>
    let createdAt: Date
    /// Apple's identifier for the place, and the navigation target: it opens the exact
    /// place, where a name and an address can only be searched for — and searching is how
    /// a pin lands on the wrong shop.
    ///
    /// Every shop is created from one now, so the server declares it non-nullable. Kept
    /// optional here for legacy rows written before shops were Apple-resolved: one of
    /// those arriving with a null would otherwise fail the whole page rather than one
    /// directions button.
    let placeId: String?
}

struct ShopSummaryDto: Decodable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let address: String
    let rate: Wrapped<Int>
    let placeId: String?
}

struct ShopDetailDto: Decodable {
    let shop: ShopDto
    let isSaved: Bool
}
