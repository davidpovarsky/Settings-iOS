import SwiftUI
import SharedSettingsKit

struct SecuritySettingsView: View {
    @ObservedObject private var biometrics = BiometricSecurityService.shared

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $biometrics.isBiometricsEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "Require Face ID"))
                            Text(String(localized: "Prompt for authentication before revealing or editing API keys."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: biometrics.availableBiometricType.systemImage)
                            .foregroundStyle(.blue)
                    }
                }
            } header: {
                Text(String(localized: "Biometric Protection"))
            } footer: {
                Text(String(localized: "When enabled, accessing or changing sensitive keys requires authentication via Face ID, Touch ID, or your device passcode."))
            }

            Section {
                HStack {
                    Text(String(localized: "Keychain Accessibility"))
                    Spacer()
                    Text(String(localized: "After First Unlock"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(String(localized: "Credential Scope"))
                    Spacer()
                    Text(String(localized: "Device Only"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(String(localized: "Ecosystem Access"))
                    Spacer()
                    Text(String(localized: "Shared Team Group"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(String(localized: "Storage Security Policy"))
            } footer: {
                Text(String(localized: "Credentials never leave this device unencrypted and are isolated to applications signed by your Apple Developer team."))
            }
        }
        .navigationTitle(String(localized: "Ecosystem Credential Security"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
