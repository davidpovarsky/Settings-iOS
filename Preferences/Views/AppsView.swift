//
//  AppsView.swift
//  Preferences
//
//  Settings > Apps
//

import SwiftUI
import SharedSettingsKit

/// View for Settings > Apps
///
/// Displays the iTorah ecosystem applications (ChavrusaChat, Pinkha, ChavrusaText, Maktabah)
/// with full search filtering and native iOS app settings navigation.
struct AppsView: View {
    @State private var searchText = ""
    private let path = "/System/Library/Settings/InstalledApps.settings"
    
    private let ecosystemApps: [AppDescriptor] = AppDescriptor.allKnownApps
    
    private var filteredApps: [AppDescriptor] {
        guard !searchText.isEmpty else { return ecosystemApps }
        return ecosystemApps.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText) ||
            $0.summary.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        CustomList(title: String(localized: "Apps")) {
            // MARK: Default Apps
            if searchText.isEmpty {
                Section {
                    SLink(
                        String(localized: "Default Apps"),
                        icon: "com.apple.graphic-icon.default-apps",
                        subtitle: String(localized: "Manage default apps on device"),
                        destination: DefaultAppsView()
                    )
                }
            }
            
            // MARK: Ecosystem Apps
            if filteredApps.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(filteredApps, id: \.id) { app in
                        SLink(
                            app.displayName,
                            icon: app.iconSymbol,
                            subtitle: app.bundleIdentifier,
                            status: String(localized: "App Group Synced"),
                            destination: AppDetailView(app: app)
                        )
                    }
                } header: {
                    Text(String(localized: "iTorah Ecosystem Apps"))
                }
            }
            
            // MARK: Hidden Apps
            if searchText.isEmpty {
                if UIDevice.IsSimulator {
                    Button {} label: {
                        SLink(String(localized: "Hidden Apps"), icon: "com.apple.graphic-icon.hidden-apps") {}
                    }
                    .foregroundStyle(.primary)
                } else {
                    SLink(String(localized: "Hidden Apps"), icon: "com.apple.graphic-icon.hidden-apps") {
                        ContentUnavailableView(
                            String(localized: "Hidden Apps"),
                            systemImage: "square.stack.3d.up.slash.fill",
                            description: Text(String(localized: "Hidden Apps"))
                        )
                    }
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: UIDevice.iPhone ? .automatic : .toolbar,
            prompt: String(localized: "Search Apps")
        )
        .scrollIndicators(.hidden)
    }
}

#Preview {
    NavigationStack {
        AppsView()
    }
}
