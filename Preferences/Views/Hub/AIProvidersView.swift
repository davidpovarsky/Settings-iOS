import SwiftUI
import SharedSettingsKit

struct AIProvidersView: View {
    @State private var providers: [ProviderDescriptor] = []
    @State private var showingAddCustomSheet = false
    @State private var customProviderName = ""
    @State private var customBaseURL = ""

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
                Text(String(localized: "Standard AI Providers"))
            } footer: {
                Text(String(localized: "Shared AI credentials are accessible by Hanlin, Pinkha, and family apps when enabled."))
            }

            Section {
                Button {
                    customProviderName = ""
                    customBaseURL = ""
                    showingAddCustomSheet = true
                } label: {
                    Label(String(localized: "Add Custom Provider"), systemImage: "plus.circle.fill")
                }
            } header: {
                Text(String(localized: "Custom Endpoints"))
            }
        }
        .navigationTitle(String(localized: "AI Providers"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadProviders()
        }
        .sheet(isPresented: $showingAddCustomSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField(String(localized: "Provider Name"), text: $customProviderName)
                        TextField(String(localized: "Base URL"), text: $customBaseURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } header: {
                        Text(String(localized: "Provider Details"))
                    } footer: {
                        Text(String(localized: "Custom OpenAI-compatible providers can be used by apps that support custom endpoints."))
                    }
                }
                .navigationTitle(String(localized: "Add Custom Provider"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Cancel")) {
                            showingAddCustomSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Add")) {
                            addCustomProvider()
                        }
                        .disabled(customProviderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func loadProviders() {
        providers = ProviderRegistry.shared.providers(in: .ai)
    }

    private func addCustomProvider() {
        let name = customProviderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let id = ProviderIdentifier.customAI(named: name)
        let descriptor = ProviderDescriptor(
            id: id,
            category: .ai,
            displayName: name,
            description: "Custom provider configured at \(customBaseURL)",
            symbolName: "server.rack",
            defaultBaseURL: URL(string: customBaseURL)
        )
        ProviderRegistry.shared.register(descriptor)

        if let url = URL(string: customBaseURL) {
            SharedPreferencesStore.shared.setCustomBaseURL(url, for: id)
        }

        loadProviders()
        showingAddCustomSheet = false
    }
}
