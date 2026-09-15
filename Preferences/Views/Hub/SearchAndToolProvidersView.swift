import SwiftUI
import SharedSettingsKit

struct SearchProvidersView: View {
    @State private var providers: [ProviderDescriptor] = []

    var body: some View {
        List {
            Section {
                ForEach(providers) { provider in
                    NavigationLink {
                        ProviderDetailView(provider: provider)
                    } label: {
                        HStack {
                            Image(systemName: provider.symbolName)
                                .foregroundStyle(.blue)
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                    .font(.body)
                                Text(provider.description)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if SharedCredentials.has(provider.id) {
                                Text(String(localized: "Configured"))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.green)
                            } else {
                                Text(String(localized: "Not Configured"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text(String(localized: "Search Providers"))
            } footer: {
                Text(String(localized: "Configure search API keys for Perplexity, Exa, and Tavily."))
            }
        }
        .navigationTitle(String(localized: "Search Providers"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            providers = ProviderRegistry.shared.providers(in: .search)
        }
    }
}

struct DeveloperServicesView: View {
    @State private var providers: [ProviderDescriptor] = []

    var body: some View {
        List {
            Section {
                ForEach(providers) { provider in
                    NavigationLink {
                        ProviderDetailView(provider: provider)
                    } label: {
                        HStack {
                            Image(systemName: provider.symbolName)
                                .foregroundStyle(.blue)
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                    .font(.body)
                                Text(provider.description)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if SharedCredentials.has(provider.id) {
                                Text(String(localized: "Configured"))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.green)
                            } else {
                                Text(String(localized: "Not Configured"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text(String(localized: "Developer Services & Telemetry"))
            } footer: {
                Text(String(localized: "Configure LangSmith, Helicone, and GitHub API credentials."))
            }
        }
        .navigationTitle(String(localized: "Developer Services & Telemetry"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            providers = ProviderRegistry.shared.providers(in: .tool)
        }
    }
}
