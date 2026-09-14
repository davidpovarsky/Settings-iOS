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
                                Text("Configured")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.green)
                            } else {
                                Text("Not Configured")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Search APIs")
            } footer: {
                Text("Search keys provide web research capabilities for Hanlin agent tools and Maktabah.")
            }
        }
        .navigationTitle("Search Providers")
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
                                Text("Configured")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.green)
                            } else {
                                Text("Not Configured")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Tool & Developer Services")
            } footer: {
                Text("Developer tokens allow agent tooling, code search, and location services across apps.")
            }
        }
        .navigationTitle("Developer Services")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            providers = ProviderRegistry.shared.providers(in: .tool)
        }
    }
}

struct AccountsAndSignInsView: View {
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
                                Text("Configured")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.green)
                            } else {
                                Text("Not Configured")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Shared Accounts")
            } footer: {
                Text("Ecosystem-level user accounts and synchronizer identities.")
            }
        }
        .navigationTitle("Accounts & Sign-ins")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            providers = ProviderRegistry.shared.providers(in: .account)
        }
    }
}
