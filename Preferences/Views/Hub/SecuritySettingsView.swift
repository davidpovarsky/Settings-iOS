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
                            Text("Require \(biometrics.availableBiometricType.displayName)")
                            Text("Prompt for authentication before revealing or editing API keys.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: biometrics.availableBiometricType.systemImage)
                            .foregroundStyle(.blue)
                    }
                }
            } header: {
                Text("Biometric Protection")
            } footer: {
                Text("When enabled, accessing or changing sensitive keys requires authentication via Face ID, Touch ID, or your device passcode.")
            }

            Section {
                HStack {
                    Text("Keychain Accessibility")
                    Spacer()
                    Text("After First Unlock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Credential Scope")
                    Spacer()
                    Text("Device Only")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Ecosystem Access")
                    Spacer()
                    Text("Shared Team Group")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Storage Security Policy")
            } footer: {
                Text("Credentials never leave this device unencrypted and are isolated to applications signed by your Apple Developer team.")
            }
        }
        .navigationTitle("Credential Security")
        .navigationBarTitleDisplayMode(.inline)
    }
}
