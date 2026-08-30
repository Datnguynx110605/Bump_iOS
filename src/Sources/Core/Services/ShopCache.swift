import Foundation

@MainActor
@Observable
final class ShopCache {
    private(set) var shops: [UUID: ShopDto] = [:]
    private var inFlight: [UUID: Task<ShopDto?, Never>] = [:]
    private let shopService: ShopService

    init(shopService: ShopService) {
        self.shopService = shopService
    }

    func shop(_ id: UUID) async -> ShopDto? {
        if let cached = shops[id] { return cached }
        if let task = inFlight[id] { return await task.value }

        let task = Task<ShopDto?, Never> { [shopService] in
            try? await shopService.shop(id: id).shop
        }
        inFlight[id] = task
        let result = await task.value
        inFlight[id] = nil
        if let result { shops[id] = result }
        return result
    }
}
