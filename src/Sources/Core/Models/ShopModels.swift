import Foundation

struct ShopDto: Decodable, Identifiable {
    let id: UUID
    let name: String
    let address: String
    let rate: Wrapped<Int>
    let createdAt: Date
}

struct ShopSummaryDto: Decodable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let address: String
    let rate: Wrapped<Int>
}

struct ShopDetailDto: Decodable {
    let shop: ShopDto
    let isSaved: Bool
}
