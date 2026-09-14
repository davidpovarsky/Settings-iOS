import Foundation

/// Thread-safe in-memory storage backend for unit testing and cross-platform mock environments.
public final class InMemoryCredentialBackend: CredentialStorageBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    public init() {}

    private func fullKey(key: String, accessGroup: String?) -> String {
        let group = accessGroup ?? "default"
        return "\(group)::\(key)"
    }

    public func get(key: String, accessGroup: String?) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[fullKey(key: key, accessGroup: accessGroup)]
    }

    public func set(data: Data, key: String, accessGroup: String?) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[fullKey(key: key, accessGroup: accessGroup)] = data
    }

    public func delete(key: String, accessGroup: String?) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: fullKey(key: key, accessGroup: accessGroup))
    }

    public func contains(key: String, accessGroup: String?) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage[fullKey(key: key, accessGroup: accessGroup)] != nil
    }

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}
