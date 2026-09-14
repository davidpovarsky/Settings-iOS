import SwiftUI
import SharedSettingsKit

struct AIDefaultsView: View {
    @State private var selectedProvider: ProviderIdentifier = .openAI
    @State private var defaultModel: String = "gpt-4o"
    @State private var selectedFallback: ProviderIdentifier? = nil

    private let availableProviders = ProviderRegistry.shared.providers(in: .ai)

    var body: some View {
        Form {
            Section {
                Picker("Primary AI Provider", selection: $selectedProvider) {
                    ForEach(availableProviders) { provider in
                        Text(provider.displayName).tag(provider.id)
                    }
                }

                HStack {
                    Text("Default Model")
                    Spacer()
                    TextField("Model Name", text: $defaultModel)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Picker("Fallback Provider", selection: $selectedFallback) {
                    Text("None").tag(ProviderIdentifier?.none)
                    ForEach(availableProviders) { provider in
                        Text(provider.displayName).tag(ProviderIdentifier?.some(provider.id))
                    }
                }
            } header: {
                Text("Default Model & Provider")
            } footer: {
                Text("Apps in the iTorah ecosystem will default to this model and provider unless overridden in app settings.")
            }
        }
        .navigationTitle("AI Defaults")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedProvider = SharedPreferencesStore.shared.defaultAIProvider
            defaultModel = SharedPreferencesStore.shared.defaultAIModel
            selectedFallback = SharedPreferencesStore.shared.fallbackAIProvider
        }
        .onChange(of: selectedProvider) { _, newValue in
            SharedPreferencesStore.shared.defaultAIProvider = newValue
        }
        .onChange(of: defaultModel) { _, newValue in
            SharedPreferencesStore.shared.defaultAIModel = newValue
        }
        .onChange(of: selectedFallback) { _, newValue in
            SharedPreferencesStore.shared.fallbackAIProvider = newValue
        }
    }
}

struct CommonServicesView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Shared App Group")
                    Spacer()
                    Text("group.com.itorah.shared")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Keychain Access Group")
                    Spacer()
                    Text("com.itorah.shared.credentials")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("CloudKit Container")
                    Spacer()
                    Text("iCloud.com.itorah.shared")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Ecosystem Shared Domains")
            } footer: {
                Text("These identifiers allow secure cross-app communication across all iTorah apps signed by Apple Team NA6HPWARQ2.")
            }
        }
        .navigationTitle("Common Services")
        .navigationBarTitleDisplayMode(.inline)
    }
}
