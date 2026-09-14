import Foundation

/// Central secure Keychain-backed store for all ecosystem credentials.
///
/// Ensures secrets are stored solely in the shared Keychain access group
/// and never placed into UserDefaults, App Groups, Plists, or logs.
public final class SharedCredentialStore: @unchecked Sendable {
    public static let shared = SharedCredentialStore()

    public static let defaultAccessGroup = "NA6HPWARQ2.com.itorah.shared.credentials"

    private let backend: CredentialStorageBackend
    private let accessGroup: String?

    public init(
        backend: CredentialStorageBackend = KeychainCredentialBackend(),
        accessGroup: String? = defaultAccessGroup
    ) {
        self.backend = backend
        self.accessGroup = accessGroup
    }

    // MARK: - Core Public API

    /// Retrieves a secret credential for a specified provider.
    public func credential(for id: ProviderIdentifier) throws -> String? {
        guard let data = try backend.get(key: id.rawValue, accessGroup: accessGroup) else {
            return nil
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidEncoding
        }
        return string
    }

    /// Stores a secret credential for a specified provider.
    public func setCredential(_ secret: String, for id: ProviderIdentifier) throws {
        guard let data = secret.data(using: .utf8) else {
            throw KeychainError.invalidEncoding
        }
        try backend.set(data: data, key: id.rawValue, accessGroup: accessGroup)
    }

    /// Deletes the credential for a specified provider.
    public func deleteCredential(for id: ProviderIdentifier) throws {
        try backend.delete(key: id.rawValue, accessGroup: accessGroup)
    }

    /// Checks whether a credential exists without exposing its value.
    public func hasCredential(for id: ProviderIdentifier) -> Bool {
        do {
            return try backend.contains(key: id.rawValue, accessGroup: accessGroup)
        } catch {
            return false
        }
    }

    /// Returns a masked representation of the credential if one exists.
    public func maskedCredential(for id: ProviderIdentifier) -> String? {
        do {
            guard let secret = try credential(for: id) else { return nil }
            return SecretMasker.mask(secret)
        } catch {
            return nil
        }
    }
}

/// Ergonomic public facade for accessing shared credentials throughout the app family.
public enum SharedCredentials {
    public static var store: SharedCredentialStore {
        SharedCredentialStore.shared
    }

    public static func value(for id: ProviderIdentifier) throws -> String? {
        try store.credential(for: id)
    }

    public static func set(_ value: String, for id: ProviderIdentifier) throws {
        try store.setCredential(value, for: id)
    }

    public static func delete(_ id: ProviderIdentifier) throws {
        try store.deleteCredential(for: id)
    }

    public static func has(_ id: ProviderIdentifier) -> Bool {
        store.hasCredential(for: id)
    }

    public static func masked(for id: ProviderIdentifier) -> String? {
        store.maskedCredential(for: id)
    }
}
