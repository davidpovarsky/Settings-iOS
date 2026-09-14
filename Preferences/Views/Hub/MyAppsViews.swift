import SwiftUI
import SharedSettingsKit

struct AppDetailView: View {
    let app: AppDescriptor

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: app.iconSymbol)
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.displayName)
                            .font(.headline)
                        Text(app.bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                Text(app.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text("Connection Status")
                    Spacer()
                    Text("Integration Planned (Phase 2)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                }

                HStack {
                    Text("Shared Keychain")
                    Spacer()
                    Text("Ready")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Shared App Group")
                    Spacer()
                    Text("group.com.itorah.shared")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Ecosystem Integration")
            } footer: {
                Text("Phase 2 will integrate SharedSettingsKit into \(app.displayName) to consume these shared credentials automatically.")
            }

            Section {
                ForEach(app.expectedProviders, id: \.self) { providerId in
                    let descriptor = ProviderRegistry.shared.descriptor(for: providerId)
                    let isConfigured = SharedCredentials.has(providerId)

                    HStack {
                        Image(systemName: descriptor?.symbolName ?? "key.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 24)

                        Text(descriptor?.displayName ?? providerId.rawValue)
                            .font(.body)

                        Spacer()

                        if isConfigured {
                            Text("Configured")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.green)
                        } else {
                            Text("Not Set")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Expected Shared Credentials")
            } footer: {
                Text("Configure these credentials under Accounts & API so they are immediately available when this app is connected.")
            }
        }
        .navigationTitle(app.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
