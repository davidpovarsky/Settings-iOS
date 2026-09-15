//
//  DeveloperView.swift
//  Preferences
//
//  Settings > Developer
//

import SwiftUI
import SharedSettingsKit

struct DeveloperView: View {
    private let path = "/System/Library/PreferenceBundles/DeveloperSettings.bundle"
    
    var body: some View {
        CustomList(title: "Developer".localized(path: path)) {
            Section {
                SLink(
                    String(localized: "Developer Services & Telemetry"),
                    icon: "wrench.and.screwdriver",
                    subtitle: String(localized: "Configure LangSmith, Helicone, and GitHub API credentials."),
                    destination: DeveloperServicesView()
                )
                SLink(
                    String(localized: "Shared Ecosystem Storage"),
                    icon: "network",
                    subtitle: String(localized: "Shared App Group and Keychain diagnostics."),
                    destination: CommonServicesView()
                )
                SLink(
                    String(localized: "Developer Diagnostics"),
                    icon: "stethoscope",
                    subtitle: String(localized: "Diagnostics"),
                    destination: DiagnosticsView()
                )
            } header: {
                Text(String(localized: "iTorah Ecosystem Apps"))
            }
            
            Section {
                SLink(
                    String(localized: "Developer Settings"),
                    icon: "com.apple.graphic-icon.developer-tools",
                    destination: ControllerBridgeView(
                        "DeveloperSettings",
                        controller: "DTSettings",
                        title: "Developer"
                    )
                )
            } header: {
                Text(String(localized: "Apple Developer"))
            }
        }
    }
}

#Preview {
    NavigationStack {
        DeveloperView()
    }
}
