import Foundation

/// Categories of service providers supported by the ecosystem.
public enum ProviderCategory: String, CaseIterable, Codable, Sendable, CustomStringConvertible {
    case ai = "AI Providers"
    case search = "Search Providers"
    case tool = "Developer & Tools"
    case account = "Accounts & Sign-ins"

    public var description: String { rawValue }

    public var systemImage: String {
        switch self {
        case .ai:
            return "sparkles"
        case .search:
            return "magnifyingglass"
        case .tool:
            return "wrench.and.screwdriver"
        case .account:
            return "person.crop.circle"
        }
    }
}
