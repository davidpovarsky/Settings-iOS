import Foundation

/// Non-sensitive metadata about stored credentials. Never stores or logs the actual secret.
public struct CredentialMetadata: Identifiable, Hashable, Codable, Sendable {
    public var id: ProviderIdentifier { providerId }
    public let providerId: ProviderIdentifier
    public let isConfigured: Bool
    public let lastModified: Date?
    public let customEndpoint: URL?
    public let notes: String?
    public let maskedPreview: String?
    public let consumedByApps: [String]

    public init(
        providerId: ProviderIdentifier,
        isConfigured: Bool,
        lastModified: Date? = nil,
        customEndpoint: URL? = nil,
        notes: String? = nil,
        maskedPreview: String? = nil,
        consumedByApps: [String] = []
    ) {
        self.providerId = providerId
        self.isConfigured = isConfigured
        self.lastModified = lastModified
        self.customEndpoint = customEndpoint
        self.notes = notes
        self.maskedPreview = maskedPreview
        self.consumedByApps = consumedByApps
    }
}
