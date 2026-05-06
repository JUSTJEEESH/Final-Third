import Foundation
import Security
import Supabase

/// Stores Supabase auth tokens in the iOS Keychain. Used as the storage
/// backend for `SupabaseClient`'s auth module.
struct KeychainAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let service = "com.thefinalthird.app.auth"

    func store(key: String, value: Data) throws {
        try delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.unknown("Keychain store failed: \(status)")
        }
    }

    func retrieve(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw AppError.unknown("Keychain read failed: \(status)")
        }
        return item as? Data
    }

    func remove(key: String) throws {
        try delete(key: key)
    }

    private func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw AppError.unknown("Keychain delete failed: \(status)")
        }
    }
}
