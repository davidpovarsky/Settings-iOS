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
                Text("Standard AI Providers")
            } footer: {
                Text("Shared AI credentials are accessible by Hanlin, Pinkha, and family apps when enabled.")
            }

            Section {
                Button {
                    customProviderName = ""
                    customBaseURL = ""
                    showingAddCustomSheet = true
                } label: {
                    Label("Add Custom OpenAI-Compatible Provider", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Custom Endpoints")
            }
        }
        .navigationTitle("AI Providers")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadProviders()
        }
        .sheet(isPresented: $showingAddCustomSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Provider Name (e.g. Local vLLM)", text: $customProviderName)
                        TextField("Base URL (e.g. http://localhost:8000/v1)", text: $customBaseURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } header: {
                        Text("Provider Details")
                    } footer: {
                        Text("Custom OpenAI-compatible providers can be used by apps that support custom endpoints.")
                    }
                }
                .navigationTitle("Add Custom Provider")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingAddCustomSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
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
        let url = URL(string: customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines))

        let descriptor = ProviderDescriptor(
            id: id,
            category: .ai,
            displayName: name,
            description: "Custom OpenAI-compatible provider",
            symbolName: "server.rack",
            defaultBaseURL: url,
            isCustomBaseURLAllowed: true,
            consumingAppIds: ["hanlin"]
        )

        ProviderRegistry.shared.register(descriptor)
        if let url {
            SharedPreferencesStore.shared.setCustomBaseURL(url, for: id)
        }
        showingAddCustomSheet = false
        loadProviders()
    }
}
