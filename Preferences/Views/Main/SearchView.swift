//
//  SearchView.swift
//  Preferences
//
//  Settings > Search
//

import SwiftUI

struct SearchView: View {
    private let path = "/System/Library/PrivateFrameworks/SpotlightSettingsSupport.framework"
    
    var body: some View {
        CustomList(title: "SEARCH".localized(path: path, table: "SpotlightSettings")) {
            Section {
                SLink(
                    String(localized: "Search Providers"),
                    icon: "magnifyingglass",
                    subtitle: String(localized: "Configure search API keys for Perplexity, Exa, and Tavily."),
                    destination: SearchProvidersView()
                )
            } header: {
                Text(String(localized: "Search Providers"))
            }
            
            Section {
                SLink(
                    String(localized: "Spotlight"),
                    icon: "com.apple.graphic-icon.search",
                    destination: ControllerBridgeView(
                        "\(path)/SpotlightSettingsSupport",
                        controller: "SpotlightSettingsController",
                        title: "SEARCH".localized(path: path, table: "SpotlightSettings")
                    )
                )
            } header: {
                Text(String(localized: "Siri & Spotlight"))
            }
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
