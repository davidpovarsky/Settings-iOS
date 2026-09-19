//
//  WallpaperPrivateTests.swift
//  SettingsTests
//
//  Focused tests for the isolated private wallpaper integration:
//  image staging, bundled catalog discovery, capability probing crash safety,
//  and typed error reporting.
//

import Testing
import Foundation
#if canImport(UIKit)
import UIKit
#endif
@testable import Preferences

struct WallpaperPrivateTests {
    
    // MARK: - Staging Tests

    @Test
    func testStagingDirectoryCreationAndReachability() throws {
        let stager = WallpaperImageStager.shared
        let dir = try stager.stagingDirectoryURL()
        
        #expect(FileManager.default.fileExists(atPath: dir.path))
        #expect(dir.lastPathComponent == WallpaperImageStager.stagingDirectoryName)
    }

    #if canImport(UIKit)
    @MainActor
    @Test
    func testImageStagingAndCleanup() throws {
        let stager = WallpaperImageStager.shared
        let stagedURL = try stager.stageGeneratedTestImage()
        
        #expect(FileManager.default.fileExists(atPath: stagedURL.path))
        let isReachable = (try? stagedURL.checkResourceIsReachable()) ?? false
        #expect(isReachable)
        
        // Remove individual staged file
        stager.removeStagedFile(at: stagedURL)
        #expect(!FileManager.default.fileExists(atPath: stagedURL.path))
    }

    @MainActor
    @Test
    func testStaleFilesCleanup() throws {
        let stager = WallpaperImageStager.shared
        let stagedURL = try stager.stageGeneratedTestImage()
        #expect(FileManager.default.fileExists(atPath: stagedURL.path))

        // Running cleanup for files older than -1 second forces eviction
        stager.cleanupStaleFiles(olderThan: -1)
        #expect(!FileManager.default.fileExists(atPath: stagedURL.path))
    }
    #endif

    // MARK: - Catalog Tests

    @Test
    func testWallpaperCatalogDiscovery() {
        let catalog = WallpaperCatalog.shared
        let wallpapers = catalog.discoverWallpapers()
        
        // Should discover successfully without crashing
        #expect(wallpapers.count >= 0)
        for wp in wallpapers {
            #expect(!wp.id.isEmpty)
            #expect(!wp.name.isEmpty)
            #expect(WallpaperCatalog.supportedExtensions.contains(wp.url.pathExtension.lowercased()))
        }
    }

    // MARK: - Runtime Probing & Crash Safety

    @Test
    func testRuntimeProbingDoesNotCrash() {
        let runtime = WallpaperPrivateRuntime.shared
        let probe = runtime.executeFullProbe()

        #expect(probe.frameworks.count >= 3)
        #expect(probe.classes.count >= 5)
        #expect(probe.selectors.count >= 10)
    }

    @Test
    func testCapabilitiesReportGeneration() {
        let capabilities = WallpaperPrivateCapabilities.shared.probe()
        
        #expect(!capabilities.osVersion.isEmpty)
        #expect(!capabilities.darwinVersion.isEmpty)
        #expect(!capabilities.deviceModel.isEmpty)
        
        let report = capabilities.formattedReport()
        #expect(!report.isEmpty)
        #expect(report.contains("# PosterBoard Private Runtime Diagnostic Report"))
        #expect(report.contains("Path A"))
        #expect(report.contains("Path B"))
    }

    // MARK: - Typed Error & Failure Safety

    @Test
    func testTypedErrorDescriptions() {
        let stagingErr = WallpaperInstallError.imageStagingFailed(reason: "Disk full")
        #expect(stagingErr.localizedDescription.contains("Disk full"))

        let unsupportedErr = WallpaperInstallError.unsupported(reason: "Missing PosterBoard")
        #expect(unsupportedErr.localizedDescription.contains("Missing PosterBoard"))

        let systemErr = WallpaperInstallError.systemServiceCallFailed(
            domain: "com.apple.posterboardservices",
            code: 403,
            message: "Entitlement missing",
            userInfo: ["key": "val"]
        )
        #expect(systemErr.localizedDescription.contains("403"))
        #expect(systemErr.failureDetails?.domain == "com.apple.posterboardservices")
        #expect(systemErr.failureDetails?.code == 403)
        #expect(systemErr.failureDetails?.userInfo["key"] == "val")
    }

    @Test
    func testAddWallpaperFailsGracefullyOnInvalidSource() async {
        let installer = WallpaperPosterInstaller.shared
        let fakeURL = URL(fileURLWithPath: "/nonexistent/test_wallpaper.png")
        
        do {
            _ = try await installer.addWallpaper(from: fakeURL)
            Issue.record("Expected addWallpaper to throw on non-existent file")
        } catch let error as WallpaperInstallError {
            switch error {
            case .imageStagingFailed(let reason):
                #expect(reason.contains("does not exist"))
            default:
                break
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Reachability & UI Bridge Tests

    @Test
    func testServiceReachabilityAuditAndClassification() {
        let reachability = WallpaperServiceReachability.shared
        let audit = reachability.audit()

        // Audit should execute safely without crashing
        #expect(audit.xpcStatus.displayText != "")
        
        // Error classification of PRSService:1
        let prs1Error = NSError(domain: "PRSService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Service remote target failed"])
        let classified = reachability.classifyError(prs1Error)
        switch classified {
        case .blockedBySandbox(let reason):
            #expect(reason.contains("PRSService:1"))
        default:
            Issue.record("Expected PRSService:1 to be classified as blockedBySandbox, got \(classified)")
        }

        // Install error classification
        let installErr = WallpaperInstallError.systemServiceCallFailed(
            domain: "PRSService",
            code: 1,
            message: "XPC failed",
            userInfo: [:]
        )
        let classifiedInstallErr = reachability.classifyError(installErr)
        switch classifiedInstallErr {
        case .blockedBySandbox(let reason):
            #expect(reason.contains("PRSService:1"))
        default:
            Issue.record("Expected WallpaperInstallError PRSService:1 to be classified as blockedBySandbox")
        }
    }

    @Test
    func testUIBridgeSafeInspection() {
        let uiBridge = WallpaperPosterUIBridge.shared
        _ = uiBridge.isGallerySupported()
        _ = uiBridge.isPreviewSupported()
        uiBridge.dismissActiveModalController()
    }

    @Test
    func testCapabilitiesReportIncludesReachability() {
        let caps = WallpaperPrivateCapabilities.shared.probe()
        let report = caps.formattedReport()

        #expect(report.contains("PosterBoardUIServices"))
        #expect(report.contains("SpringBoardUIServices"))
        if caps.serviceReachability != nil {
            #expect(report.contains("XPC Service Reachability & Sandbox Audit"))
        }
    }
}
