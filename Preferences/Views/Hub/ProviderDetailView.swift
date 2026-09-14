import SwiftUI
import SharedSettingsKit

struct ProviderDetailView: View {
    let provider: ProviderDescriptor

    @State private var hasKey: Bool = false
    @State private var maskedKey: String = ""
    @State private var revealedKey: String? = nil
    @State private var isRevealed: Bool = false

    @State private var customBaseURLString: String = ""
    @State private var showingKeySheet: Bool = false
    @State private var newKeyInput: String = ""
    @State private var showingDeleteConfirmation: Bool = false

    @State private var isValidating: Bool = false
    @State private var validationResult: ProviderValidationService.ValidationResult? = nil
    @State private var showingValidationAlert: Bool = false

    @ObservedObject private var biometrics = BiometricSecurityService.shared

    var body: some View {
        Form {
            // MARK: - Status & Credential Section
            Section {
                HStack {
                    Label {
                        Text("Status")
                    } icon: {
                        Image(systemName: provider.symbolName)
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    if hasKey {
                        Text("Configured")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)
                    } else {
                        Text("Not Configured")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if hasKey {
                    HStack {
                        Text("API Key")
                        Spacer()
                        if isRevealed, let revealed = revealedKey {
                            Text(revealed)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            Text(maskedKey)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        toggleRevealKey()
                    } label: {
                        HStack {
                            Image(systemName: isRevealed ? "eye.slash" : "eye")
                            Text(isRevealed ? "Hide Key" : "Reveal Key")
                        }
                    }

                    Button {
                        newKeyInput = ""
                        showingKeySheet = true
                    } label: {
                        Text("Replace Key")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Text("Delete Key")
                    }
                } else {
                    Button {
                        newKeyInput = ""
                        showingKeySheet = true
                    } label: {
                        Label("Configure API Key", systemImage: "key.fill")
                    }
                }
            } header: {
                Text("Credential")
            } footer: {
                Text("Secrets are securely stored in the shared iTorah Keychain and never written to plists, logs, or backups.")
            }

            // MARK: - Validation Action
            if hasKey {
                Section {
                    Button {
                        validateConfiguration()
                    } label: {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text("Test Configuration")
                        }
                    }
                    .disabled(isValidating)
                } footer: {
                    Text("Directly validates connectivity and authentication with \(provider.displayName).")
                }
            }

            // MARK: - Endpoint / Base URL Section
            if provider.isCustomBaseURLAllowed {
                Section {
                    TextField("Base URL", text: $customBaseURLString)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    if let defaultURL = provider.defaultBaseURL {
                        Button("Reset to Default") {
                            customBaseURLString = defaultURL.absoluteString
                            saveCustomURL()
                        }
                        .disabled(customBaseURLString == defaultURL.absoluteString)
                    }
                } header: {
                    Text("Endpoint URL")
                } footer: {
                    if let defaultURL = provider.defaultBaseURL {
                        Text("Default: \(defaultURL.absoluteString)")
                    }
                }
            }

            // MARK: - Consuming Applications
            if !provider.consumingAppIds.isEmpty {
                Section {
                    ForEach(provider.consumingAppIds, id: \.self) { appId in
                        let app = AppDescriptor.allKnownApps.first(where: { $0.id == appId })
                        HStack {
                            Image(systemName: app?.iconSymbol ?? "app.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app?.displayName ?? appId)
                                    .font(.body)
                                Text(app?.summary ?? "Ecosystem application")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Planned")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(UIColor.secondarySystemFill))
                                .clipShape(Capsule())
                        }
                    }
                } header: {
                    Text("Used By")
                } footer: {
                    Text("Shared credentials will be accessible by these apps when connected in Phase 2.")
                }
            }

            // MARK: - Provider Info & Documentation
            Section {
                Text(provider.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let helpURL = provider.helpURL {
                    Link(destination: helpURL) {
                        HStack {
                            Text("Get API Key / Documentation")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("About \(provider.displayName)")
            }
        }
        .navigationTitle(provider.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reloadState()
        }
        .onChange(of: customBaseURLString) { _, _ in
            saveCustomURL()
        }
        .sheet(isPresented: $showingKeySheet) {
            NavigationStack {
                Form {
                    Section {
                        SecureField("Enter API Key or Secret", text: $newKeyInput)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } header: {
                        Text("Enter Credential")
                    } footer: {
                        Text("Paste your secret key from \(provider.displayName).")
                    }
                }
                .navigationTitle(hasKey ? "Replace Key" : "Set Key")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingKeySheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveNewKey()
                        }
                        .disabled(newKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .confirmationDialog(
            "Are you sure you want to delete this key?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Key", role: .destructive) {
                deleteKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Any apps relying on this shared credential will no longer have access to \(provider.displayName).")
        }
        .alert(
            "Configuration Test Result",
            isPresented: $showingValidationAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            switch validationResult {
            case .success(let message):
                Text(message)
            case .failure(let error):
                Text(error)
            case .unsupported(let reason):
                Text(reason)
            case .none:
                Text("Validation completed.")
            }
        }
    }

    // MARK: - Actions

    private func reloadState() {
        hasKey = SharedCredentials.has(provider.id)
        maskedKey = SharedCredentials.masked(for: provider.id) ?? ""
        isRevealed = false
        revealedKey = nil

        if let savedURL = SharedPreferencesStore.shared.customBaseURL(for: provider.id) {
            customBaseURLString = savedURL.absoluteString
        } else if let defaultURL = provider.defaultBaseURL {
            customBaseURLString = defaultURL.absoluteString
        }
    }

    private func toggleRevealKey() {
        if isRevealed {
            isRevealed = false
            revealedKey = nil
            return
        }

        Task {
            let authenticated = await biometrics.authenticate(
                reason: "Authenticate to view the secret API key for \(provider.displayName)"
            )
            if authenticated {
                revealedKey = try? SharedCredentials.value(for: provider.id)
                isRevealed = true
            }
        }
    }

    private func saveNewKey() {
        let trimmed = newKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try SharedCredentials.set(trimmed, for: provider.id)
            SharedPreferencesStore.shared.setIsConfigured(true, for: provider.id)
            showingKeySheet = false
            reloadState()
        } catch {
            // Handle save error gracefully
        }
    }

    private func deleteKey() {
        do {
            try SharedCredentials.delete(provider.id)
            SharedPreferencesStore.shared.setIsConfigured(false, for: provider.id)
            reloadState()
        } catch {
            // Handle error gracefully
        }
    }

    private func saveCustomURL() {
        guard provider.isCustomBaseURLAllowed else { return }
        if let url = URL(string: customBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
           !customBaseURLString.isEmpty {
            SharedPreferencesStore.shared.setCustomBaseURL(url, for: provider.id)
        } else if customBaseURLString.isEmpty {
            SharedPreferencesStore.shared.setCustomBaseURL(nil, for: provider.id)
        }
    }

    private func validateConfiguration() {
        isValidating = true
        Task {
            guard let key = try? SharedCredentials.value(for: provider.id) else {
                isValidating = false
                return
            }
            let customURL = URL(string: customBaseURLString)
            let result = await ProviderValidationService.validate(
                id: provider.id,
                apiKey: key,
                customBaseURL: customURL
            )
            validationResult = result
            isValidating = false
            showingValidationAlert = true
        }
    }
}
