import Foundation
import Security

/// Small wrapper around generic-password Keychain items for this app.
enum KeychainStore {
    enum KeychainError: LocalizedError {
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                return String(localized: "Keychain error \(Int(status)): \(SecCopyErrorMessageString(status, nil) as String? ?? "unknown")")
            }
        }
    }

    private static let service = "com.bilgaaaaa.deskfocus"

    static func save(_ data: Data, account: String) throws {
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeychainError.unexpectedStatus(updateStatus) }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
    }

    static func load(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                Log.google.error("Keychain read failed with status \(status)")
            }
            return nil
        }
        return result as? Data
    }

    static func delete(account: String) {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Log.google.error("Keychain delete failed with status \(status)")
        }
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
