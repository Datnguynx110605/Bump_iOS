import Foundation
import Security

struct StoredTokens {
    let accessToken: String
    let refreshToken: String
}

final class KeychainTokenStore {
    private let service = "com.bump.client.auth"
    private let accessAccount = "accessToken"
    private let refreshAccount = "refreshToken"

    func load() -> StoredTokens? {
        guard let access = read(account: accessAccount), let refresh = read(account: refreshAccount) else {
            return nil
        }
        return StoredTokens(accessToken: access, refreshToken: refresh)
    }

    func save(_ tokens: StoredTokens) {
        write(tokens.accessToken, account: accessAccount)
        write(tokens.refreshToken, account: refreshAccount)
    }

    func clear() {
        delete(account: accessAccount)
        delete(account: refreshAccount)
    }

    private func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Carried on the update path too: `SecItemUpdate` leaves attributes it isn't
        // given alone, so without this an existing install keeps the weaker
        // backup-restorable accessibility it was first written with, for good.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            var newItem = query
            newItem[kSecValueData as String] = data
            // `…ThisDeviceOnly` keeps the pair out of encrypted backups and iCloud
            // Keychain, so a restored backup cannot carry a live session onto a second
            // device. Still `AfterFirstUnlock`, so a background refresh still reads it.
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
