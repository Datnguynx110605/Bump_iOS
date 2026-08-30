import Foundation

struct Wrapped<T: Decodable>: Decodable {
    let value: T
}

extension Wrapped: Equatable where T: Equatable {}
extension Wrapped: Hashable where T: Hashable {}

extension Wrapped: CustomStringConvertible where T: CustomStringConvertible {
    var description: String { value.description }
}
