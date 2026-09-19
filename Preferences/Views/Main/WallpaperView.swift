//
//  WallpaperView.swift
//  Preferences
//
//  Settings > Wallpaper
//

import SwiftUI

struct WallpaperView: View {
    @State private var showingCustomWallpapers = false
    @State private var refreshID = UUID()

    var body: some View {
        ControllerBridgeView(
            "WallpaperSettings",
            controller: "WallpaperSettingsRootViewController",
            title: "Wallpaper"
        )
        .id(refreshID)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCustomWallpapers = true
                } label: {
                    Label("Custom", systemImage: "photo.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingCustomWallpapers) {
            NavigationStack {
                CustomWallpapersView {
                    refreshID = UUID()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WallpaperView()
    }
}

