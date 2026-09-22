import Foundation

struct ShopDto: Decodable, Identifiable {
    let id: UUID
    let name: String
    let address: String
    let rate: Wrapped<Int>
    let createdAt: Date
    /// Apple's identifier for the place, present only on a shop the server resolved from
    /// Apple rather than took on trust. It is both the verification mark and the
    /// navigation target: it opens the exact place, where a name and an address can only
    /// be searched for — and searching is how a pin lands on the wrong shop.
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
