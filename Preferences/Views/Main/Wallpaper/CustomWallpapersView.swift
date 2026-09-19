//
//  CustomWallpapersView.swift
//  Preferences
//
//  SwiftUI management surface for discovering bundled wallpapers,
//  inspecting PosterBoard runtime capabilities, and installing wallpapers.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct CustomWallpapersView: View {
    @Environment(\.dismiss) private var dismiss

    public var onInstalled: (() -> Void)?

    @State private var capabilities: WallpaperRuntimeCapabilities?
    @State private var bundledWallpapers: [BundledWallpaper] = []
    @State private var isRunningOperation = false
    @State private var operationStatusText = ""
    @State private var lastInstallResult: WallpaperInstallResult?
    @State private var lastError: WallpaperInstallError?
    @State private var showingCopiedToast = false
    @State private var isDiagnosticsExpanded = false

    private let installer = WallpaperPosterInstaller.shared
    private let catalog = WallpaperCatalog.shared
    private let stager = WallpaperImageStager.shared

    public init(onInstalled: (() -> Void)? = nil) {
        self.onInstalled = onInstalled
    }

    public var body: some View {
        List {
            // MARK: - Active Operation Banner
            if isRunningOperation {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(operationStatusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - Last Result / Error Banner
            if let result = lastInstallResult {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Wallpaper Installed Successfully")
                                .font(.headline)
                        }

                        Text("Strategy: \(result.installPath.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let uuid = result.serverUUID {
                            Text("Poster UUID: \(uuid.uuidString)")
                                .font(.caption2)
                                .fontDesign(.monospaced)
                                .foregroundStyle(.secondary)
                        }

                        if let provider = result.providerBundleIdentifier {
                            Text("Provider: \(provider)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text("Active Selection: \(result.isSelected ? "Yes (Add & Use)" : "No (Add Only)")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Installation Outcome")
                }
            } else if let error = lastError {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text("Installation Failed")
                                .font(.headline)
                        }

                        Text(error.localizedDescription)
                            .font(.footnote)
                            .foregroundStyle(.primary)

                        if let details = error.failureDetails {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Domain: \(details.domain)")
                                Text("Code: \(details.code)")
                                if !details.userInfo.isEmpty {
                                    Text("UserInfo: \(details.userInfo.description)")
                                }
                            }
                            .font(.caption2)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Error Details")
                }
            }

            // MARK: - Runtime Status
            Section {
                if let caps = capabilities {
                    statusRow(
                        title: "PosterBoardServices",
                        isAvailable: caps.frameworks.first(where: { $0.name == "PosterBoardServices" })?.isLoaded == true
                    )
                    statusRow(
                        title: "PRSService Class",
                        isAvailable: caps.classes.first(where: { $0.name == "PRSService" })?.exists == true
                    )
                    statusRow(
                        title: "PRSPosterUpdate Class",
                        isAvailable: caps.classes.first(where: { $0.name == "PRSPosterUpdate" })?.exists == true
                    )
                    statusRow(
                        title: "Direct Path A (PRSExternalSystemService)",
                        isAvailable: caps.canAttemptPathA
                    )
                    statusRow(
                        title: "Underlying Path B (PRSService)",
                        isAvailable: caps.canAttemptPathB
                    )

                    Button {
                        refreshCapabilities()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Run Probe")
                        }
                    }
                    .disabled(isRunningOperation)

                    Button {
                        copyDiagnosticReport(caps)
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text(showingCopiedToast ? "Diagnostic Report Copied!" : "Copy Diagnostic Report")
                        }
                    }
                    .disabled(isRunningOperation)

                    DisclosureGroup("Discovered Selectors (\(caps.discoveredSelectors.count))", isExpanded: $isDiagnosticsExpanded) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("OS: \(caps.osVersion)")
                                .font(.caption)
                            Text("Darwin: \(caps.darwinVersion)")
                                .font(.caption)
                            Text("Model: \(caps.deviceModel)")
                                .font(.caption)

                            Divider()

                            ForEach(caps.discoveredSelectors.prefix(40)) { sel in
                                let kind = sel.isClassMethod ? "+" : "-"
                                Text("\(kind)[\(sel.className) \(sel.selectorName)]")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    ProgressView("Probing PosterBoard capabilities...")
                }
            } header: {
                Text("Runtime Status")
            } footer: {
                Text("Probes dynamic private framework symbols and underlying XPC methods on this device.")
            }

            // MARK: - Test Wallpaper
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: [.indigo, .purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 50, height: 75)
                            .overlay(
                                Image(systemName: "photo.artframe")
                                    .foregroundStyle(.white.opacity(0.8))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Generated Test Wallpaper")
                                .font(.headline)
                            Text("Code-rendered gradient wallpaper with timestamp and device ID.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            installTestWallpaper(selectAfterCreation: false)
                        } label: {
                            Text("Add Only")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRunningOperation)

                        Button {
                            installTestWallpaper(selectAfterCreation: true)
                        } label: {
                            Text("Add & Use")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRunningOperation)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Test Wallpaper")
            } footer: {
                Text("Installs a code-generated wallpaper directly without requiring any pre-bundled binary images.")
            }

            // MARK: - Bundled Wallpapers
            Section {
                if bundledWallpapers.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No bundled wallpapers found.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Add .png, .jpg, or .heic files to 'Preferences/Resources/Wallpapers' in Xcode to see them here.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(bundledWallpapers) { wallpaper in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                #if canImport(UIKit)
                                if let image = catalog.loadImage(for: wallpaper, thumbnailSize: CGSize(width: 50, height: 75)) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 75)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    placeholderThumbnail
                                }
                                #else
                                placeholderThumbnail
                                #endif

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(wallpaper.name)
                                        .font(.headline)
                                    Text(wallpaper.id)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if wallpaper.fileSize > 0 {
                                        Text(ByteCountFormatter.string(fromByteCount: wallpaper.fileSize, countStyle: .file))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            HStack(spacing: 12) {
                                Button {
                                    installBundledWallpaper(wallpaper, selectAfterCreation: false)
                                } label: {
                                    Text("Add to Wallpapers")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isRunningOperation)

                                Button {
                                    installBundledWallpaper(wallpaper, selectAfterCreation: true)
                                } label: {
                                    Text("Add & Use")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(isRunningOperation)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Bundled Wallpapers (\(bundledWallpapers.count))")
            } footer: {
                Text("Wallpapers packaged with this app build. 'Add Only' keeps your existing wallpaper active; 'Add & Use' activates it immediately.")
            }
        }
        .navigationTitle("Custom Wallpapers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            refreshCapabilities()
            loadBundledWallpapers()
        }
    }

    // MARK: - Subviews

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 50, height: 75)
            .overlay(
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            )
    }

    private func statusRow(title: String, isAvailable: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if isAvailable {
                Text("Available")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Text("Unavailable")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Actions

    private func refreshCapabilities() {
        capabilities = installer.capabilities()
    }

    private func loadBundledWallpapers() {
        bundledWallpapers = catalog.discoverWallpapers()
    }

    private func copyDiagnosticReport(_ caps: WallpaperRuntimeCapabilities) {
        #if canImport(UIKit)
        UIPasteboard.general.string = caps.formattedReport()
        withAnimation {
            showingCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingCopiedToast = false
        }
        #endif
    }

    private func installTestWallpaper(selectAfterCreation: Bool) {
        #if canImport(UIKit)
        isRunningOperation = true
        operationStatusText = "Generating & installing test wallpaper..."
        lastInstallResult = nil
        lastError = nil

        Task {
            do {
                let result = try await installer.addTestWallpaper(selectAfterCreation: selectAfterCreation)
                await MainActor.run {
                    self.lastInstallResult = result
                    self.isRunningOperation = false
                    self.onInstalled?()
                }
            } catch let error as WallpaperInstallError {
                await MainActor.run {
                    self.lastError = error
                    self.isRunningOperation = false
                }
            } catch {
                await MainActor.run {
                    self.lastError = .unsupported(reason: error.localizedDescription)
                    self.isRunningOperation = false
                }
            }
        }
        #endif
    }

    private func installBundledWallpaper(_ wallpaper: BundledWallpaper, selectAfterCreation: Bool) {
        isRunningOperation = true
        operationStatusText = "Installing '\(wallpaper.name)'..."
        lastInstallResult = nil
        lastError = nil

        Task {
            do {
                let result = try await installer.addBundledWallpaper(wallpaper, selectAfterCreation: selectAfterCreation)
                await MainActor.run {
                    self.lastInstallResult = result
                    self.isRunningOperation = false
                    self.onInstalled?()
                }
            } catch let error as WallpaperInstallError {
                await MainActor.run {
                    self.lastError = error
                    self.isRunningOperation = false
                }
            } catch {
                await MainActor.run {
                    self.lastError = .unsupported(reason: error.localizedDescription)
                    self.isRunningOperation = false
                }
            }
        }
    }
}
