import XCTest
@testable import SharedSettingsKit

final class SharedSettingsKitTests: XCTestCase {
    var inMemoryBackend: InMemoryCredentialBackend!
    var credentialStore: SharedCredentialStore!
    var preferencesStore: SharedPreferencesStore!

    override func setUp() {
        super.setUp()
        inMemoryBackend = InMemoryCredentialBackend()
        credentialStore = SharedCredentialStore(
            backend: inMemoryBackend,
            accessGroup: "test.group"
        )
        preferencesStore = SharedPreferencesStore(appGroupName: "test.group.shared")
        preferencesStore.clearAll()
    }

    override func tearDown() {
        preferencesStore?.clearAll()
        inMemoryBackend = nil
        credentialStore = nil
        preferencesStore = nil
        super.tearDown()
    }

    // MARK: - 1. Save, Read, Update, Delete Credential

    func testCredentialLifecycle() throws {
        let provider = ProviderIdentifier.openAI
        let secretKey = "sk-test-1234567890abcdef"

        // Initially absent
        XCTAssertNil(try credentialStore.credential(for: provider))
        XCTAssertFalse(credentialStore.hasCredential(for: provider))

        // Save
        try credentialStore.setCredential(secretKey, for: provider)
        XCTAssertEqual(try credentialStore.credential(for: provider), secretKey)
        XCTAssertTrue(credentialStore.hasCredential(for: provider))

        // Update
        let updatedKey = "sk-test-updated-9876543210fedcba"
        try credentialStore.setCredential(updatedKey, for: provider)
        XCTAssertEqual(try credentialStore.credential(for: provider), updatedKey)

        // Delete
        try credentialStore.deleteCredential(for: provider)
        XCTAssertNil(try credentialStore.credential(for: provider))
        XCTAssertFalse(credentialStore.hasCredential(for: provider))
    }

    // MARK: - 2. Duplicate / Repeated Writes

    func testDuplicateWrites() throws {
        let provider = ProviderIdentifier.gemini
        let initial = "AIzaSyTestKey1"

        try credentialStore.setCredential(initial, for: provider)
        // Repeat write with identical value
        try credentialStore.setCredential(initial, for: provider)
        XCTAssertEqual(try credentialStore.credential(for: provider), initial)

        // Repeated writes with different values
        for i in 1...5 {
            try credentialStore.setCredential("key-\(i)", for: provider)
            XCTAssertEqual(try credentialStore.credential(for: provider), "key-\(i)")
        }
    }

    // MARK: - 3. Credential Presence & Masking

    func testCredentialPresenceAndMasking() throws {
        let provider = ProviderIdentifier.anthropic
        let testKey = "sk-ant-api03-1234567890abcdefghij"

        XCTAssertNil(credentialStore.maskedCredential(for: provider))

        try credentialStore.setCredential(testKey, for: provider)
        XCTAssertTrue(credentialStore.hasCredential(for: provider))

        let masked = credentialStore.maskedCredential(for: provider)
        XCTAssertNotNil(masked)
        XCTAssertTrue(masked!.contains("••••"))
        XCTAssertFalse(masked!.contains("1234567890"))
    }

    // MARK: - 4. Redaction Helper

    func testRedaction() {
        let longSecret = "sk-proj-super-confidential-token-123456"
        let masked = SecretMasker.mask(longSecret, visiblePrefix: 3, visibleSuffix: 4)

        XCTAssertTrue(masked.hasPrefix("sk-"))
        XCTAssertTrue(masked.hasSuffix("3456"))
        XCTAssertTrue(masked.contains("••••••••"))
        XCTAssertFalse(masked.contains("super-confidential"))

        // Short secret
        let shortSecret = "secret"
        let shortMasked = SecretMasker.mask(shortSecret)
        XCTAssertEqual(shortMasked, "••••••")

        // Full mask
        let full = SecretMasker.fullMask("secret123", count: 8)
        XCTAssertEqual(full, "••••••••")
    }

    // MARK: - 5. Provider Registry IDs

    func testProviderRegistry() {
        let registry = ProviderRegistry.shared

        // Standard AI providers exist
        XCTAssertNotNil(registry.descriptor(for: .openAI))
        XCTAssertNotNil(registry.descriptor(for: .gemini))
        XCTAssertNotNil(registry.descriptor(for: .anthropic))
        XCTAssertNotNil(registry.descriptor(for: .deepSeek))

        // Stable machine IDs check
        XCTAssertEqual(ProviderIdentifier.openAI.rawValue, "ai.openai.primary")
        XCTAssertEqual(ProviderIdentifier.gemini.rawValue, "ai.gemini.primary")
        XCTAssertEqual(ProviderIdentifier.anthropic.rawValue, "ai.anthropic.primary")
        XCTAssertEqual(ProviderIdentifier.tavily.rawValue, "search.tavily.primary")
        XCTAssertEqual(ProviderIdentifier.gitHub.rawValue, "tool.github.primary")

        // Categories
        let aiProviders = registry.providers(in: .ai)
        XCTAssertTrue(aiProviders.contains { $0.id == .openAI })
        XCTAssertTrue(aiProviders.contains { $0.id == .gemini })

        let searchProviders = registry.providers(in: .search)
        XCTAssertTrue(searchProviders.contains { $0.id == .tavily })

        // Custom provider registration
        let customId = ProviderIdentifier.customAI(named: "local-vllm")
        registry.register(ProviderDescriptor(
            id: customId,
            category: .ai,
            displayName: "Local vLLM",
            description: "Self-hosted model server.",
            symbolName: "server.rack",
            defaultBaseURL: URL(string: "http://192.168.1.50:8000/v1")
        ))

        XCTAssertNotNil(registry.descriptor(for: customId))
        XCTAssertEqual(registry.descriptor(for: customId)?.displayName, "Local vLLM")
    }

    // MARK: - 6. Shared Preferences Store

    func testSharedPreferences() {
        let store = preferencesStore!

        // Default AI selection
        XCTAssertEqual(store.defaultAIProvider, .openAI)
        store.defaultAIProvider = .gemini
        XCTAssertEqual(store.defaultAIProvider, .gemini)

        // Custom base URL
        let customURL = URL(string: "https://my-proxy.com/v1")!
        XCTAssertNil(store.customBaseURL(for: .openAI))
        store.setCustomBaseURL(customURL, for: .openAI)
        XCTAssertEqual(store.customBaseURL(for: .openAI), customURL)

        // Configured flag
        XCTAssertFalse(store.isConfigured(for: .deepSeek))
        store.setIsConfigured(true, for: .deepSeek)
        XCTAssertTrue(store.isConfigured(for: .deepSeek))

        // Schema version
        XCTAssertEqual(store.schemaVersion, 1)
        store.schemaVersion = 2
        XCTAssertEqual(store.schemaVersion, 2)
    }

    // MARK: - 7. Migration Scaffolding

    func testMigrationCoordinator() throws {
        let coordinator = MigrationCoordinator(
            credentialStore: credentialStore,
            preferencesStore: preferencesStore
        )

        let migrationId = "test.migration.v1"
        XCTAssertFalse(preferencesStore.isMigrationCompleted(identifier: migrationId))

        // First run: migrates keys
        let entries = [
            (providerId: ProviderIdentifier.openAI, secret: "sk-legacy-openai", endpoint: URL(string: "https://api.openai.com/v1")),
            (providerId: ProviderIdentifier.tavily, secret: "tvly-legacy-key", endpoint: nil as URL?)
        ]

        let result1 = try coordinator.migrateLegacyEntries(
            migrationIdentifier: migrationId,
            entries: entries
        )

        XCTAssertEqual(result1.migratedCount, 2)
        XCTAssertEqual(result1.skippedCount, 0)
        XCTAssertFalse(result1.wasAlreadyCompleted)
        XCTAssertTrue(preferencesStore.isMigrationCompleted(identifier: migrationId))
        XCTAssertEqual(try credentialStore.credential(for: .openAI), "sk-legacy-openai")
        XCTAssertEqual(try credentialStore.credential(for: .tavily), "tvly-legacy-key")

        // Idempotent second run: skips completely
        let result2 = try coordinator.migrateLegacyEntries(
            migrationIdentifier: migrationId,
            entries: entries
        )
        XCTAssertEqual(result2.migratedCount, 0)
        XCTAssertEqual(result2.skippedCount, 2)
        XCTAssertTrue(result2.wasAlreadyCompleted)
    }

    // MARK: - 8. Graceful Missing Credential & Error Handling

    func testGracefulHandling() throws {
        let unconfigured = ProviderIdentifier(rawValue: "ai.nonexistent.id")

        // Reading non-existent key returns nil, does not throw
        XCTAssertNil(try credentialStore.credential(for: unconfigured))
        XCTAssertFalse(credentialStore.hasCredential(for: unconfigured))

        // Deleting non-existent key succeeds gracefully
        XCTAssertNoThrow(try credentialStore.deleteCredential(for: unconfigured))
    }

    // MARK: - 9. Safe Diagnostics

    func testDiagnosticsService() throws {
        try credentialStore.setCredential("sk-valid", for: .openAI)
        preferencesStore.setIsConfigured(true, for: .openAI)

        let service = DiagnosticsService(
            credentialStore: credentialStore,
            preferencesStore: preferencesStore,
            registry: ProviderRegistry.shared
        )

        let report = service.generateReport()
        let text = report.formattedText()

        // Diagnostics should contain metadata
        XCTAssertTrue(text.contains("iTorah Settings Diagnostics"))
        XCTAssertTrue(text.contains("ai.openai.primary: CONFIGURED"))

        // Diagnostics MUST NEVER contain raw secret!
        XCTAssertFalse(text.contains("sk-valid"))
    }
}
