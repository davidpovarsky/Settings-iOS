import Foundation

/// App Group-backed store for non-sensitive shared configuration, preferences, and metadata.
///
/// Backed by the shared App Group container `group.com.itorah.shared`.
/// Secrets must NEVER be stored here.
public final class SharedPreferencesStore: @unchecked Sendable {
    public static let shared = SharedPreferencesStore()

    public static let defaultAppGroupName = "group.com.itorah.shared"

    private let userDefaults: UserDefaults?
    private let fallbackLock = NSLock()
    private var inMemoryFallback: [String: Any] = [:]

    public init(appGroupName: String = defaultAppGroupName) {
        self.userDefaults = UserDefaults(suiteName: appGroupName)
    }

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    // MARK: - Generic Value Accessors

    private func object(forKey key: String) -> Any? {
        if let userDefaults {
            return userDefaults.object(forKey: key)
        }
        fallbackLock.lock()
        defer { fallbackLock.unlock() }
        return inMemoryFallback[key]
    }

    private func set(object: Any?, forKey key: String) {
        if let userDefaults {
            if let object {
                userDefaults.set(object, forKey: key)
            } else {
                userDefaults.removeObject(forKey: key)
            }
            return
        }
        fallbackLock.lock()
        defer { fallbackLock.unlock() }
        if let object {
            inMemoryFallback[key] = object
        } else {
            inMemoryFallback.removeValue(forKey: key)
        }
    }

    // MARK: - Provider Custom Base URLs

    private func customBaseURLKey(for id: ProviderIdentifier) -> String {
        "provider.baseURL.\(id.rawValue)"
    }

    public func customBaseURL(for id: ProviderIdentifier) -> URL? {
        guard let string = object(forKey: customBaseURLKey(for: id)) as? String else {
            return nil
        }
        return URL(string: string)
    }

    public func setCustomBaseURL(_ url: URL?, for id: ProviderIdentifier) {
        set(object: url?.absoluteString, forKey: customBaseURLKey(for: id))
    }

    // MARK: - Provider Configured Status Cache

    private func isConfiguredKey(for id: ProviderIdentifier) -> String {
        "provider.isConfigured.\(id.rawValue)"
    }

    public func isConfigured(for id: ProviderIdentifier) -> Bool {
        (object(forKey: isConfiguredKey(for: id)) as? Bool) ?? false
    }

    public func setIsConfigured(_ configured: Bool, for id: ProviderIdentifier) {
        set(object: configured, forKey: isConfiguredKey(for: id))
    }

    // MARK: - AI Defaults

    private let defaultAIProviderKey = "ai.defaults.primaryProvider"
    private let defaultAIModelKey = "ai.defaults.primaryModel"
    private let fallbackAIProviderKey = "ai.defaults.fallbackProvider"

    public var defaultAIProvider: ProviderIdentifier {
        get {
            guard let raw = object(forKey: defaultAIProviderKey) as? String else {
                return .openAI
            }
            return ProviderIdentifier(rawValue: raw)
        }
        set {
            set(object: newValue.rawValue, forKey: defaultAIProviderKey)
        }
    }

    public var defaultAIModel: String {
        get {
            (object(forKey: defaultAIModelKey) as? String) ?? "gpt-4o"
        }
        set {
            set(object: newValue, forKey: defaultAIModelKey)
        }
    }

    public var fallbackAIProvider: ProviderIdentifier? {
        get {
            guard let raw = object(forKey: fallbackAIProviderKey) as? String else {
                return nil
            }
            return ProviderIdentifier(rawValue: raw)
        }
        set {
            set(object: newValue?.rawValue, forKey: fallbackAIProviderKey)
        }
    }

    // MARK: - Schema & Migration Tracking

    private let schemaVersionKey = "schema.version"
    private func migrationKey(_ id: String) -> String {
        "migration.\(id).completed"
    }

    public var schemaVersion: Int {
        get { (object(forKey: schemaVersionKey) as? Int) ?? 1 }
        set { set(object: newValue, forKey: schemaVersionKey) }
    }

    public func isMigrationCompleted(identifier: String) -> Bool {
        (object(forKey: migrationKey(identifier)) as? Bool) ?? false
    }

    public func markMigrationCompleted(identifier: String) {
        set(object: true, forKey: migrationKey(identifier))
    }

    // MARK: - App Group Availability

    public var isAppGroupAccessible: Bool {
        userDefaults != nil
    }

    /// Clears stored preferences (primarily used for unit test isolation).
    public func clearAll() {
        if let userDefaults {
            let dict = userDefaults.dictionaryRepresentation()
            for key in dict.keys {
                userDefaults.removeObject(forKey: key)
            }
        }
        fallbackLock.lock()
        defer { fallbackLock.unlock() }
        inMemoryFallback.removeAll()
    }
}

