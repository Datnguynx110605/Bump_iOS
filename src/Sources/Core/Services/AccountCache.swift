import Foundation

@MainActor
@Observable
final class AccountCache {
    private(set) var accounts: [UUID: AccountSummaryDto] = [:]
    private var inFlight: [UUID: Task<AccountSummaryDto?, Never>] = [:]
    private let accountService: AccountService

    init(accountService: AccountService) {
        self.accountService = accountService
    }

    func account(_ id: UUID) async -> AccountSummaryDto? {
        if let cached = accounts[id] { return cached }
        if let task = inFlight[id] { return await task.value }

        let task = Task<AccountSummaryDto?, Never> { [accountService] in
            try? await accountService.account(id: id)
        }
        inFlight[id] = task
        let result = await task.value
        inFlight[id] = nil
        if let result { accounts[id] = result }
        return result
    }

    func store(_ account: AccountSummaryDto) {
        accounts[account.id] = account
    }

    /// Dropped on sign-out: the viewer's own profile is in here, and the next account
    /// would otherwise see the previous one's name and avatar on its own rows.
    func reset() {
        accounts = [:]
        inFlight = [:]
    }
}
