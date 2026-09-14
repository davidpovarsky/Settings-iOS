import Foundation

/// Service for generating safe system diagnostics without revealing confidential keys.
public final class DiagnosticsService: @unchecked Sendable {
    private let credentialStore: SharedCredentialStore
    private let preferencesStore: SharedPreferencesStore
    private let registry: ProviderRegistry

    public init(
        credentialStore: SharedCredentialStore = .shared,
        preferencesStore: SharedPreferencesStore = .shared,
        registry: ProviderRegistry = .shared
    ) {
        self.credentialStore = credentialStore
        self.preferencesStore = preferencesStore
        self.registry = registry
    }

    public struct Report: Codable, Sendable {
        public let bundleIdentifier: String
        public let appVersion: String
        public let buildNumber: String
        public let appGroupIdentifier: String
        public let isAppGroupAccessible: Bool
        public let keychainAccessGroup: String
        public let schemaVersion: Int
        public let configuredProviders: [String: Bool]
        public let generatedAt: Date

        public func formattedText() -> String {
            """
            --- iTorah Settings Diagnostics ---
            Generated: \(generatedAt)
            Bundle ID: \(bundleIdentifier)
            Version: \(appVersion) (\(buildNumber))
            App Group: \(appGroupIdentifier) [\(isAppGroupAccessible ? "OK" : "NOT FOUND")]
            Keychain Group: \(keychainAccessGroup)
            Schema Version: \(schemaVersion)

            Configured Providers:
            \(configuredProviders.sorted { $0.key < $1.key }.map { "  - \($0.key): \($0.value ? "CONFIGURED" : "NOT SET")" }.joined(separator: "\n"))
            -----------------------------------
            """
        }
    }

    public func generateReport() -> Report {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.itorah.settings"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        var configuredMap: [String: Bool] = [:]
        for provider in registry.allProviders() {
            let hasCred = credentialStore.hasCredential(for: provider.id)
            let isFlagged = preferencesStore.isConfigured(for: provider.id)
            configuredMap[provider.id.rawValue] = hasCred || isFlagged
        }

        return Report(
            bundleIdentifier: bundleId,
            appVersion: version,
            buildNumber: build,
            appGroupIdentifier: SharedPreferencesStore.defaultAppGroupName,
            isAppGroupAccessible: preferencesStore.isAppGroupAccessible,
            keychainAccessGroup: SharedCredentialStore.defaultAccessGroup,
            schemaVersion: preferencesStore.schemaVersion,
            configuredProviders: configuredMap,
            generatedAt: Date()
        )
    }
}
