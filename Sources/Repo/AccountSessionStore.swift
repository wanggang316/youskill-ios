import Foundation
import Security

protocol AccountSessionStoring: Sendable {
    func load() -> AccountSession?
    func save(_ session: AccountSession) throws
    func delete()
}

enum KeychainError: Error, Equatable {
    case status(OSStatus)
}

/// Keeps the account tokens in the Keychain, available after the first unlock so
/// sync can run when the app returns from the background.
struct KeychainAccountSessionStore: AccountSessionStoring {
    private let service: String
    private let account = "account-session"

    init(service: String = "\(AppConfiguration.bundleIdentifier).account") {
        self.service = service
    }

    func load() -> AccountSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? AppJSONCoders.decoder.decode(AccountSession.self, from: data)
    }

    func save(_ session: AccountSession) throws {
        let data = try AppJSONCoders.encoder.encode(session)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true
        ]
    }
}
