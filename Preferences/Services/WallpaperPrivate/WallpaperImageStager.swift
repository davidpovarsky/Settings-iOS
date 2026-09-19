//
//  WallpaperImageStager.swift
//  Preferences
//
//  Stages and validates image files in an app-owned cache directory
//  prior to passing local file URLs to PosterBoard.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Prepares, validates, and manages temporary local file URLs for PosterBoard ingestion.
public final class WallpaperImageStager: Sendable {
    public static let shared = WallpaperImageStager()

    public static let stagingDirectoryName = "WallpaperPrivateStaging"

    private let fileManager = FileManager.default

    public init() {}

    // MARK: - Staging Directory

    /// Returns the staging directory URL inside Library/Caches, creating it if needed.
    public func stagingDirectoryURL() throws -> URL {
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw WallpaperInstallError.imageStagingFailed(reason: "Could not access user Caches directory.")
        }

        let dir = cachesURL.appendingPathComponent(Self.stagingDirectoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            do {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw WallpaperInstallError.imageStagingFailed(
                    reason: "Failed to create staging directory at '\(dir.path)': \(error.localizedDescription)"
                )
            }
        }
        return dir
    }

    // MARK: - Staging Operations

    /// Stages an image file from a source URL into a new uniquely named file in the staging directory.
    public func stageImage(from sourceURL: URL) throws -> URL {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw WallpaperInstallError.imageStagingFailed(
                reason: "Source image does not exist at '\(sourceURL.path)'."
            )
        }

        let isReachable = (try? sourceURL.checkResourceIsReachable()) ?? true
        guard isReachable else {
            throw WallpaperInstallError.imageStagingFailed(
                reason: "Source image at '\(sourceURL.path)' is not reachable."
            )
        }

        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension.lowercased()
        let uniqueName = "staged-\(UUID().uuidString).\(ext)"
        let targetDir = try stagingDirectoryURL()
        let destinationURL = targetDir.appendingPathComponent(uniqueName)

        do {
            // Copy source file to staging destination
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw WallpaperInstallError.imageStagingFailed(
                reason: "Could not copy image from '\(sourceURL.path)' to '\(destinationURL.path)': \(error.localizedDescription)"
            )
        }

        // Verify staged file
        guard fileManager.fileExists(atPath: destinationURL.path) else {
            throw WallpaperInstallError.imageStagingFailed(
                reason: "Staged destination file was not found after copy at '\(destinationURL.path)'."
            )
        }

        let destReachable = (try? destinationURL.checkResourceIsReachable()) ?? true
        guard destReachable else {
            throw WallpaperInstallError.imageStagingFailed(
                reason: "Staged destination file at '\(destinationURL.path)' is not reachable."
            )
        }

        SettingsLogger.info("Staged wallpaper image to '\(destinationURL.path)'")
        return destinationURL
    }

    /// Stages an in-memory UIImage by writing it as PNG data into the staging directory.
    #if canImport(UIKit)
    public func stageImage(_ image: UIImage) throws -> URL {
        guard let data = image.pngData() else {
            throw WallpaperInstallError.imageStagingFailed(reason: "Could not encode UIImage to PNG data.")
        }

        let uniqueName = "staged-\(UUID().uuidString).png"
        let targetDir = try stagingDirectoryURL()
        let destinationURL = targetDir.appendingPathComponent(uniqueName)

        do {
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            throw WallpaperInstallError.imageStagingFailed(
                reason: "Could not write PNG data to '\(destinationURL.path)': \(error.localizedDescription)"
            )
        }

        guard fileManager.fileExists(atPath: destinationURL.path) else {
            throw WallpaperInstallError.imageStagingFailed(
                reason: "Staged PNG file does not exist after writing at '\(destinationURL.path)'."
            )
        }

        SettingsLogger.info("Staged UIImage to '\(destinationURL.path)'")
        return destinationURL
    }
    #endif

    /// Safely cleans up stale staged files older than the specified time interval (default: 1 hour).
    public func cleanupStaleFiles(olderThan seconds: TimeInterval = 3600) {
        guard let targetDir = try? stagingDirectoryURL() else { return }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: targetDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let expirationDate = Date().addingTimeInterval(-seconds)

        for fileURL in contents {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < expirationDate {
                try? fileManager.removeItem(at: fileURL)
                SettingsLogger.info("Removed stale staged file at '\(fileURL.lastPathComponent)'")
            }
        }
    }

    /// Deletes a specific staged file after an operation completes.
    public func removeStagedFile(at url: URL) {
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
            SettingsLogger.info("Cleaned up staged file at '\(url.lastPathComponent)'")
        }
    }

    // MARK: - Test Wallpaper Generator

    /// Generates a crisp, visually distinct test wallpaper rendered in code without binary assets.
    #if canImport(UIKit)
    @MainActor
    public func generateTestWallpaperImage() -> UIImage {
        let size = CGSize(width: 1170, height: 2532) // iPhone 16/17 Pro portrait resolution
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let cg = context.cgContext

            // 1. Draw rich background gradient
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradientColors = [
                UIColor(red: 0.05, green: 0.08, blue: 0.18, alpha: 1.0).cgColor,
                UIColor(red: 0.12, green: 0.22, blue: 0.45, alpha: 1.0).cgColor,
                UIColor(red: 0.38, green: 0.18, blue: 0.48, alpha: 1.0).cgColor,
                UIColor(red: 0.06, green: 0.10, blue: 0.22, alpha: 1.0).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.35, 0.70, 1.0]

            if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locations) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            // 2. Draw subtle decorative circles
            cg.saveGState()
            cg.setBlendMode(.screen)
            cg.setFillColor(UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 0.15).cgColor)
            cg.fillEllipse(in: CGRect(x: -150, y: 300, width: 700, height: 700))

            cg.setFillColor(UIColor(red: 0.8, green: 0.3, blue: 0.7, alpha: 0.12).cgColor)
            cg.fillEllipse(in: CGRect(x: size.width - 500, y: 1200, width: 800, height: 800))
            cg.restoreGState()

            // 3. Draw border frame
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.25).cgColor)
            cg.setLineWidth(4.0)
            let frameRect = CGRect(x: 40, y: 80, width: size.width - 80, height: size.height - 160)
            cg.stroke(frameRect)

            // 4. Draw Typography
            let titleParagraph = NSMutableParagraphStyle()
            titleParagraph.alignment = .center

            let titleFont = UIFont.systemFont(ofSize: 56, weight: .bold)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: titleParagraph
            ]

            let subFont = UIFont.systemFont(ofSize: 32, weight: .medium)
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: subFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                .paragraphStyle: titleParagraph
            ]

            let metaFont = UIFont.monospacedSystemFont(ofSize: 24, weight: .regular)
            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: metaFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.65),
                .paragraphStyle: titleParagraph
            ]

            let titleString = "TEST WALLPAPER"
            let subString = "Settings-iOS PosterBoard Integration"

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let timestamp = dateFormatter.string(from: Date())
            let metaString = "Rendered: \(timestamp)\nUUID: \(UUID().uuidString.prefix(8))\niOS Poster Configuration Test"

            let textY = size.height * 0.42
            (titleString as NSString).draw(
                in: CGRect(x: 60, y: textY, width: size.width - 120, height: 80),
                withAttributes: titleAttrs
            )

            (subString as NSString).draw(
                in: CGRect(x: 60, y: textY + 90, width: size.width - 120, height: 60),
                withAttributes: subAttrs
            )

            (metaString as NSString).draw(
                in: CGRect(x: 60, y: textY + 170, width: size.width - 120, height: 120),
                withAttributes: metaAttrs
            )
        }
    }

    /// Programmatically generates and stages the test wallpaper, returning its file URL.
    @MainActor
    public func stageGeneratedTestImage() throws -> URL {
        let image = generateTestWallpaperImage()
        return try stageImage(image)
    }
    #endif
}
