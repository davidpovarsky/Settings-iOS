import SwiftUI
import SharedSettingsKit

struct AppDetailView: View {
    let app: AppDescriptor
    @Environment(\.openURL) private var openURL

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
                    Text(String(localized: "Connection Status"))
                    Spacer()
                    Text(String(localized: "App Group Synced"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                }

                HStack {
                    Text(String(localized: "Shared Keychain"))
                    Spacer()
                    Text(String(localized: "Ready"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(String(localized: "Shared App Group"))
                    Spacer()
                    Text("group.com.itorah.shared")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(String(localized: "Ecosystem Integration"))
            } footer: {
                Text(String(localized: "Secrets are securely stored in the shared iTorah Keychain and never written to plists, logs, or backups."))
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
                            Text(String(localized: "Configured"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.green)
                        } else {
                            Text(String(localized: "Not Set"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(String(localized: "Expected Shared Credentials"))
            } footer: {
                Text(String(localized: "Configure these credentials under Apple Intelligence so they are immediately available when this app is connected."))
            }

            Section {
                Button {
                    if let url = URL(string: "\(app.id)://") {
                        openURL(url)
                    }
                } label: {
                    Label(String(localized: "Open App"), systemImage: "arrow.up.forward.app")
                }
            }
        }
        .navigationTitle(app.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
