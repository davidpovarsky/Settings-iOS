import Foundation
#if canImport(Security)
import Security
#endif

/// Production implementation of `CredentialStorageBackend` using the Apple Keychain.
public final class KeychainCredentialBackend: CredentialStorageBackend, @unchecked Sendable {
    private let service: String

    public init(service: String = "com.itorah.shared.credentials") {
        self.service = service
    }

    public func get(key: String, accessGroup: String?) throws -> Data? {
        #if canImport(Security)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup, !accessGroup.isEmpty {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledStatus(status)
        }
        #else
        return nil
        #endif
    }

    public func set(data: Data, key: String, accessGroup: String?) throws {
        #if canImport(Security)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        if let accessGroup, !accessGroup.isEmpty {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unhandledStatus(status)
        }
        #endif
    }

    public func delete(key: String, accessGroup: String?) throws {
        #if canImport(Security)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        if let accessGroup, !accessGroup.isEmpty {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
        #endif
    }

    public func contains(key: String, accessGroup: String?) throws -> Bool {
        #if canImport(Security)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup, !accessGroup.isEmpty {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
        #else
        return false
        #endif
    }
}

public enum KeychainError: LocalizedError, Sendable {
    case unhandledStatus(Int32)
    case invalidEncoding

    public var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            return "Keychain operation failed with OSStatus \(status)."
        case .invalidEncoding:
            return "Unable to encode or decode credential string data."
        }
    }
}
