import Foundation

/// Rich metadata describing a service provider in the registry.
public struct ProviderDescriptor: Identifiable, Hashable, Codable, Sendable {
    public var id: ProviderIdentifier
    public var category: ProviderCategory
    public var displayName: String
    public var description: String
    public var symbolName: String
    public var defaultBaseURL: URL?
    public var isCustomBaseURLAllowed: Bool
    public var helpURL: URL?
    public var consumingAppIds: [String]

    public init(
        id: ProviderIdentifier,
        category: ProviderCategory,
        displayName: String,
        description: String,
        symbolName: String,
        defaultBaseURL: URL? = nil,
        isCustomBaseURLAllowed: Bool = false,
        helpURL: URL? = nil,
        consumingAppIds: [String] = []
    ) {
        self.id = id
        self.category = category
        self.displayName = displayName
        self.description = description
        self.symbolName = symbolName
        self.defaultBaseURL = defaultBaseURL
        self.isCustomBaseURLAllowed = isCustomBaseURLAllowed
        self.helpURL = helpURL
        self.consumingAppIds = consumingAppIds
    }
}
