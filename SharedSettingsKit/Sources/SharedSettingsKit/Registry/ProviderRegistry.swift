import Foundation

/// Central registry mapping stable `ProviderIdentifier`s to rich provider metadata.
public final class ProviderRegistry: @unchecked Sendable {
    public static let shared = ProviderRegistry()

    private let lock = NSLock()
    private var providers: [ProviderIdentifier: ProviderDescriptor] = [:]

    public init() {
        registerDefaultProviders()
    }

    public func register(_ descriptor: ProviderDescriptor) {
        lock.lock()
        defer { lock.unlock() }
        providers[descriptor.id] = descriptor
    }

    public func descriptor(for id: ProviderIdentifier) -> ProviderDescriptor? {
        lock.lock()
        defer { lock.unlock() }
        return providers[id]
    }

    public func allProviders() -> [ProviderDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return Array(providers.values)
    }

    public func providers(in category: ProviderCategory) -> [ProviderDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return providers.values
            .filter { $0.category == category }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func registerDefaultProviders() {
        // MARK: - AI Providers
        register(ProviderDescriptor(
            id: .openAI,
            category: .ai,
            displayName: "OpenAI",
            description: "Industry-standard models including GPT-4o and reasoning models.",
            symbolName: "cpu",
            defaultBaseURL: URL(string: "https://api.openai.com/v1"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://platform.openai.com/api-keys"),
            consumingAppIds: ["hanlin", "pinkha", "chavrusatext", "maktabah"]
        ))

        register(ProviderDescriptor(
            id: .gemini,
            category: .ai,
            displayName: "Google Gemini",
            description: "High-speed multimodal and deep reasoning models from Google.",
            symbolName: "sparkles",
            defaultBaseURL: URL(string: "https://generativelanguage.googleapis.com"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://aistudio.google.com/app/apikey"),
            consumingAppIds: ["hanlin", "pinkha", "chavrusatext"]
        ))

        register(ProviderDescriptor(
            id: .anthropic,
            category: .ai,
            displayName: "Anthropic Claude",
            description: "Claude 3.5 Sonnet & Claude 3 Opus with advanced coding and nuanced analysis.",
            symbolName: "brain.head.profile",
            defaultBaseURL: URL(string: "https://api.anthropic.com/v1"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://console.anthropic.com/settings/keys"),
            consumingAppIds: ["hanlin", "pinkha"]
        ))

        register(ProviderDescriptor(
            id: .deepSeek,
            category: .ai,
            displayName: "DeepSeek",
            description: "Cost-effective open and reasoning models (DeepSeek-V3, DeepSeek-R1).",
            symbolName: "waveform.path.ecg",
            defaultBaseURL: URL(string: "https://api.deepseek.com/v1"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://platform.deepseek.com/api_keys"),
            consumingAppIds: ["hanlin"]
        ))

        register(ProviderDescriptor(
            id: .zhipuAI,
            category: .ai,
            displayName: "Zhipu AI (GLM)",
            description: "Bilingual GLM reasoning and multimodal foundational models.",
            symbolName: "network",
            defaultBaseURL: URL(string: "https://open.bigmodel.cn/api/paas/v4"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://bigmodel.cn/usercenter/proj-mgmt/apikeys"),
            consumingAppIds: ["hanlin"]
        ))

        register(ProviderDescriptor(
            id: .qwen,
            category: .ai,
            displayName: "Qwen (DashScope)",
            description: "Alibaba Cloud large language and visual understanding models.",
            symbolName: "cloud.fill",
            defaultBaseURL: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://dashscope.console.aliyun.com/apiKey"),
            consumingAppIds: ["hanlin"]
        ))

        register(ProviderDescriptor(
            id: .siliconCloud,
            category: .ai,
            displayName: "SiliconCloud",
            description: "High-throughput cloud inference for open-source AI models.",
            symbolName: "bolt.horizontal.fill",
            defaultBaseURL: URL(string: "https://api.siliconflow.cn/v1"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://cloud.siliconflow.cn/account/ak"),
            consumingAppIds: ["hanlin"]
        ))

        register(ProviderDescriptor(
            id: .groq,
            category: .ai,
            displayName: "Groq",
            description: "Ultra-low-latency LPU inference for open models.",
            symbolName: "bolt.fill",
            defaultBaseURL: URL(string: "https://api.groq.com/openai/v1"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://console.groq.com/keys"),
            consumingAppIds: ["hanlin"]
        ))

        register(ProviderDescriptor(
            id: .ollama,
            category: .ai,
            displayName: "Ollama (Local)",
            description: "Local model runtime running on your Mac or local network.",
            symbolName: "desktopcomputer",
            defaultBaseURL: URL(string: "http://localhost:11434/v1"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://ollama.com"),
            consumingAppIds: ["hanlin"]
        ))

        // MARK: - Search Providers
        register(ProviderDescriptor(
            id: .tavily,
            category: .search,
            displayName: "Tavily Search",
            description: "Search API engineered specifically for AI research and fact-gathering.",
            symbolName: "magnifyingglass.circle",
            defaultBaseURL: URL(string: "https://api.tavily.com"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://app.tavily.com/home"),
            consumingAppIds: ["hanlin", "maktabah"]
        ))

        register(ProviderDescriptor(
            id: .bochaAI,
            category: .search,
            displayName: "Bocha AI Search",
            description: "Web search engine API optimized for AI agent applications.",
            symbolName: "globe",
            defaultBaseURL: URL(string: "https://api.bochaai.com/v1"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://open.bochaai.com/api-keys"),
            consumingAppIds: ["hanlin"]
        ))

        register(ProviderDescriptor(
            id: .zhipuSearch,
            category: .search,
            displayName: "Zhipu Web Search",
            description: "Integrated search indexing for GLM models.",
            symbolName: "doc.text.magnifyingglass",
            defaultBaseURL: URL(string: "https://open.bigmodel.cn/api/paas/v4/web_search"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://bigmodel.cn"),
            consumingAppIds: ["hanlin"]
        ))

        // MARK: - Developer Services
        register(ProviderDescriptor(
            id: .gitHub,
            category: .tool,
            displayName: "GitHub",
            description: "Personal access tokens for source code search and repository tools.",
            symbolName: "hammer",
            defaultBaseURL: URL(string: "https://api.github.com"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://github.com/settings/tokens"),
            consumingAppIds: ["hanlin"]
        ))

        register(ProviderDescriptor(
            id: .appleMaps,
            category: .tool,
            displayName: "Apple Maps",
            description: "Native Apple Maps integration tokens.",
            symbolName: "map",
            defaultBaseURL: URL(string: "https://applemap.com"),
            isCustomBaseURLAllowed: false,
            helpURL: nil,
            consumingAppIds: ["hanlin"]
        ))

        register(ProviderDescriptor(
            id: .amap,
            category: .tool,
            displayName: "Amap (AutoNavi)",
            description: "Location and map services for regional navigation.",
            symbolName: "location.north.circle",
            defaultBaseURL: URL(string: "https://restapi.amap.com"),
            isCustomBaseURLAllowed: true,
            helpURL: URL(string: "https://console.amap.com"),
            consumingAppIds: ["hanlin"]
        ))

        // MARK: - Accounts
        register(ProviderDescriptor(
            id: .appleAccount,
            category: .account,
            displayName: "Apple Account / iCloud",
            description: "Shared iTorah CloudKit and ubiquity synchronizer identity.",
            symbolName: "applelogo",
            consumingAppIds: ["hanlin", "pinkha", "chavrusatext", "maktabah"]
        ))
    }
}
