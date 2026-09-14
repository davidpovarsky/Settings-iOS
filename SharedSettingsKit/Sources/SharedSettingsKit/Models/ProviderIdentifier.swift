import Foundation

/// Stable, typed machine identifiers for providers in the iTorah ecosystem.
///
/// Decouples internal lookup and storage keys from user-facing display names.
public struct ProviderIdentifier: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    // MARK: - AI Providers
    public static let openAI = ProviderIdentifier(rawValue: "ai.openai.primary")
    public static let gemini = ProviderIdentifier(rawValue: "ai.gemini.primary")
    public static let anthropic = ProviderIdentifier(rawValue: "ai.anthropic.primary")
    public static let deepSeek = ProviderIdentifier(rawValue: "ai.deepseek.primary")
    public static let zhipuAI = ProviderIdentifier(rawValue: "ai.zhipuai.primary")
    public static let qwen = ProviderIdentifier(rawValue: "ai.qwen.primary")
    public static let siliconCloud = ProviderIdentifier(rawValue: "ai.siliconcloud.primary")
    public static let groq = ProviderIdentifier(rawValue: "ai.groq.primary")
    public static let ollama = ProviderIdentifier(rawValue: "ai.ollama.local")

    /// Factory method for custom OpenAI-compatible providers.
    public static func customAI(named name: String) -> ProviderIdentifier {
        let clean = name.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }
        return ProviderIdentifier(rawValue: "ai.custom.\(clean)")
    }

    // MARK: - Search Providers
    public static let tavily = ProviderIdentifier(rawValue: "search.tavily.primary")
    public static let bochaAI = ProviderIdentifier(rawValue: "search.bochaai.primary")
    public static let zhipuSearch = ProviderIdentifier(rawValue: "search.zhipuai.primary")
    public static let braveSearch = ProviderIdentifier(rawValue: "search.brave.primary")

    // MARK: - Developer & Tool Services
    public static let gitHub = ProviderIdentifier(rawValue: "tool.github.primary")
    public static let appleMaps = ProviderIdentifier(rawValue: "tool.applemap.primary")
    public static let amap = ProviderIdentifier(rawValue: "tool.amap.primary")

    // MARK: - Accounts & Sign-ins
    public static let appleAccount = ProviderIdentifier(rawValue: "account.apple.primary")
    public static let customAccount = ProviderIdentifier(rawValue: "account.custom.primary")

    // MARK: - Standard List
    public static let allStandardAI: [ProviderIdentifier] = [
        .openAI,
        .gemini,
        .anthropic,
        .deepSeek,
        .zhipuAI,
        .qwen,
        .siliconCloud,
        .groq,
        .ollama
    ]

    public static let allStandardSearch: [ProviderIdentifier] = [
        .tavily,
        .bochaAI,
        .zhipuSearch,
        .braveSearch
    ]

    public static let allStandardTools: [ProviderIdentifier] = [
        .gitHub,
        .appleMaps,
        .amap
    ]

    public static let allStandardAccounts: [ProviderIdentifier] = [
        .appleAccount,
        .customAccount
    ]
}
