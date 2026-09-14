import Foundation

/// Protocol abstracting the underlying secure key-value storage.
public protocol CredentialStorageBackend: Sendable {
    func get(key: String, accessGroup: String?) throws -> Data?
    func set(data: Data, key: String, accessGroup: String?) throws
    func delete(key: String, accessGroup: String?) throws
    func contains(key: String, accessGroup: String?) throws -> Bool
}
