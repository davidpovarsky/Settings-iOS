import Foundation

/// Coordinator for safely and idempotently migrating legacy credentials into the shared store.
///
/// Designed for Phase 2 when Hanlin and sibling apps migrate their legacy storage
/// (e.g. SwiftData or private UserDefaults) into the shared Keychain.
public final class MigrationCoordinator: @unchecked Sendable {
    private let credentialStore: SharedCredentialStore
    private let preferencesStore: SharedPreferencesStore

    public init(
        credentialStore: SharedCredentialStore = .shared,
        preferencesStore: SharedPreferencesStore = .shared
    ) {
        self.credentialStore = credentialStore
        self.preferencesStore = preferencesStore
    }

    /// Result of a migration operation.
    public struct MigrationResult: Equatable, Sendable {
        public let migratedCount: Int
        public let skippedCount: Int
        public let wasAlreadyCompleted: Bool
    }

    /// Migrates a batch of legacy key-value pairs into the shared store idempotently.
    ///
    /// - Parameters:
    ///   - migrationIdentifier: A unique identifier for this migration (e.g. `"hanlin.swiftdata.v1"`).
    ///   - entries: An array of tuples containing `(providerId, legacySecret, optionalEndpoint)`.
    ///   - overwriteExisting: Whether to overwrite a shared credential if one already exists (default: `false`).
    /// - Returns: A `MigrationResult` detailing the number of keys migrated or skipped.
    @discardableResult
    public func migrateLegacyEntries(
        migrationIdentifier: String,
        entries: [(providerId: ProviderIdentifier, secret: String, endpoint: URL?)],
        overwriteExisting: Bool = false
    ) throws -> MigrationResult {
        if preferencesStore.isMigrationCompleted(identifier: migrationIdentifier) {
            return MigrationResult(migratedCount: 0, skippedCount: entries.count, wasAlreadyCompleted: true)
        }

        var migrated = 0
        var skipped = 0

        for entry in entries {
            let secret = entry.secret.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !secret.isEmpty else {
                skipped += 1
                continue
            }

            let alreadyExists = credentialStore.hasCredential(for: entry.providerId)
            if !alreadyExists || overwriteExisting {
                try credentialStore.setCredential(secret, for: entry.providerId)
                preferencesStore.setIsConfigured(true, for: entry.providerId)
                if let endpoint = entry.endpoint {
                    preferencesStore.setCustomBaseURL(endpoint, for: entry.providerId)
                }
                migrated += 1
            } else {
                skipped += 1
            }
        }

        preferencesStore.markMigrationCompleted(identifier: migrationIdentifier)
        return MigrationResult(migratedCount: migrated, skippedCount: skipped, wasAlreadyCompleted: false)
    }
}
