import Foundation

struct CursorPage<Item: Decodable>: Decodable {
    let items: [Item]
    let nextCursor: String?
    let hasMore: Bool
}
