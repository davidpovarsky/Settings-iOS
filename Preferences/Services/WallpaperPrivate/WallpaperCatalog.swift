//
//  WallpaperCatalog.swift
//  Preferences
//
//  Discovers and exposes bundled wallpaper image resources.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Scans app resources for bundled wallpapers and provides access to metadata and images.
public final class WallpaperCatalog: Sendable {
    public static let shared = WallpaperCatalog()

    public static let wallpapersDirectoryName = "Wallpapers"
    public static let supportedExtensions = ["png", "jpg", "jpeg", "heic"]

    public init() {}

    // MARK: - Discovery

    /// Scans the bundle for bundled wallpaper files matching supported extensions.
    public func discoverWallpapers() -> [BundledWallpaper] {
        var foundURLs: [URL] = []
        let bundle = Bundle.main

        // 1. Check folder reference location (Wallpapers subfolder in bundle resources)
        if let directoryURL = bundle.url(forResource: Self.wallpapersDirectoryName, withExtension: nil) {
            foundURLs.append(contentsOf: scanDirectory(at: directoryURL))
        }

        // 2. Check direct resourceURL/Wallpapers
        if let resourceURL = bundle.resourceURL {
            let directDir = resourceURL.appendingPathComponent(Self.wallpapersDirectoryName, isDirectory: true)
            if FileManager.default.fileExists(atPath: directDir.path) {
                let directURLs = scanDirectory(at: directDir)
                for u in directURLs where !foundURLs.contains(where: { $0.path == u.path }) {
                    foundURLs.append(u)
                }
            }
        }

        // 3. Fallback: query bundle directly for each extension in the Wallpapers subdirectory
        for ext in Self.supportedExtensions {
            if let urls = bundle.urls(forResourcesWithExtension: ext, subdirectory: Self.wallpapersDirectoryName) {
                for u in urls where !foundURLs.contains(where: { $0.path == u.path }) {
                    foundURLs.append(u)
                }
            }
            if let uppercaseURLs = bundle.urls(forResourcesWithExtension: ext.uppercased(), subdirectory: Self.wallpapersDirectoryName) {
                for u in uppercaseURLs where !foundURLs.contains(where: { $0.path == u.path }) {
                    foundURLs.append(u)
                }
            }
        }

        // Convert URLs to BundledWallpaper items
        let wallpapers: [BundledWallpaper] = foundURLs.compactMap { url in
            let ext = url.pathExtension.lowercased()
            guard Self.supportedExtensions.contains(ext) else { return nil }

            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            let name = url.deletingPathExtension().lastPathComponent

            return BundledWallpaper(
                id: url.lastPathComponent,
                name: name,
                url: url,
                fileSize: fileSize
            )
        }

        SettingsLogger.info("WallpaperCatalog discovered \(wallpapers.count) bundled wallpapers")
        return wallpapers.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func scanDirectory(at directoryURL: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if Self.supportedExtensions.contains(ext) {
                results.append(fileURL)
            }
        }
        return results
    }

    // MARK: - Image Loading

    #if canImport(UIKit)
    /// Loads a UIImage for a bundled wallpaper, optionally scaled as a thumbnail.
    public func loadImage(for wallpaper: BundledWallpaper, thumbnailSize: CGSize? = nil) -> UIImage? {
        guard let fullImage = UIImage(contentsOfFile: wallpaper.url.path) else {
            return nil
        }

        guard let targetSize = thumbnailSize else {
            return fullImage
        }

        // Generate scaled thumbnail
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            fullImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    #endif
}
