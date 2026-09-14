import Foundation

/// Describes an application in the iTorah family.
public struct AppDescriptor: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let displayName: String
    public let bundleIdentifier: String
    public let iconSymbol: String
    public let summary: String
    public let expectedProviders: [ProviderIdentifier]

    public init(
        id: String,
        displayName: String,
        bundleIdentifier: String,
        iconSymbol: String,
        summary: String,
        expectedProviders: [ProviderIdentifier]
    ) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.iconSymbol = iconSymbol
        self.summary = summary
        self.expectedProviders = expectedProviders
    }

    public static let hanlin = AppDescriptor(
        id: "hanlin",
        displayName: "Hanlin / ChavrusaChat",
        bundleIdentifier: "com.itorah.chavrusachat",
        iconSymbol: "bubble.left.and.bubble.right.fill",
        summary: "Universal AI Torah study partner & agent assistant.",
        expectedProviders: [
            .openAI, .gemini, .anthropic, .deepSeek, .zhipuAI, .qwen, .siliconCloud,
            .tavily, .bochaAI, .gitHub, .appleMaps, .amap
        ]
    )

    public static let pinkha = AppDescriptor(
        id: "pinkha",
        displayName: "Pinkha",
        bundleIdentifier: "com.itorah.chavrusanotes",
        iconSymbol: "note.text",
        summary: "Torah notebook, inspector & study companion.",
        expectedProviders: [.openAI, .gemini, .anthropic]
    )

    public static let chavrusaText = AppDescriptor(
        id: "chavrusatext",
        displayName: "ChavrusaText",
        bundleIdentifier: "com.davidpovarsky.chavrusatext",
        iconSymbol: "character.book.closed.fill",
        summary: "Smart text study & library viewer.",
        expectedProviders: [.openAI, .gemini]
    )

    public static let maktabah = AppDescriptor(
        id: "maktabah",
        displayName: "Maktabah",
        bundleIdentifier: "com.davidpovarsky.chavrusatext",
        iconSymbol: "books.vertical.fill",
        summary: "Offline Otzaria & Sefaria Jewish library database.",
        expectedProviders: [.openAI, .tavily]
    )

    public static let allKnownApps: [AppDescriptor] = [
        .hanlin,
        .pinkha,
        .chavrusaText,
        .maktabah
    ]
}
