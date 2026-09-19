//
//  WallpaperPrivateCapabilities.swift
//  Preferences
//
//  Gathers host environment information, evaluates private PosterBoard
//  runtime capabilities, and generates structured diagnostic reports.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Darwin)
import Darwin
#endif

/// Probes and evaluates the runtime surface for private wallpaper poster installation.
public final class WallpaperPrivateCapabilities: Sendable {
    public static let shared = WallpaperPrivateCapabilities()

    private init() {}

    // MARK: - Public API

    /// Runs a full probe of the runtime environment and returns a structured capabilities report.
    public func probe() -> WallpaperRuntimeCapabilities {
        SettingsLogger.info("Starting WallpaperPrivateCapabilities probe...")

        let osVersion = currentOSVersion()
        let darwinVersion = currentDarwinVersion()
        let deviceModel = currentDeviceModel()

        let runtime = WallpaperPrivateRuntime.shared
        let probeResult = runtime.executeFullProbe()

        // Path A evaluation (PRSExternalSystemService direct convenience method)
        let (canAttemptPathA, pathAReason) = evaluatePathA(
            classes: probeResult.classes,
            selectors: probeResult.selectors
        )

        // Path B evaluation (PRSService + PRSPosterUpdate underlying path)
        let (canAttemptPathB, pathBReason) = evaluatePathB(
            classes: probeResult.classes,
            selectors: probeResult.selectors
        )

        // Reachability & Entitlement Audit
        let reachabilityAudit = WallpaperServiceReachability.shared.audit()

        let capabilities = WallpaperRuntimeCapabilities(
            osVersion: osVersion,
            darwinVersion: darwinVersion,
            deviceModel: deviceModel,
            frameworks: probeResult.frameworks,
            classes: probeResult.classes,
            knownSelectors: probeResult.selectors,
            discoveredSelectors: probeResult.discovered,
            canAttemptPathA: canAttemptPathA,
            canAttemptPathB: canAttemptPathB,
            pathAAvailabilityReason: pathAReason,
            pathBAvailabilityReason: pathBReason,
            serviceReachability: reachabilityAudit
        )

        SettingsLogger.info("Wallpaper probe finished: Path A=\(canAttemptPathA), Path B=\(canAttemptPathB), XPC=\(reachabilityAudit.xpcStatus.displayText)")
        return capabilities
    }

    // MARK: - Evaluation Logic

    private func evaluatePathA(
        classes: [ClassStatus],
        selectors: [SelectorStatus]
    ) -> (canAttempt: Bool, reason: String) {
        guard classes.first(where: { $0.name == "PRSExternalSystemService" && $0.exists }) != nil else {
            return (false, "PRSExternalSystemService class not found")
        }

        let hasSelectorA1 = selectors.contains {
            $0.className == "PRSExternalSystemService" &&
            $0.selectorName == "createLockScreenPhotosPosterWithImageAtURL:selectLockScreenPoster:completion:" &&
            $0.exists
        }

        let hasSelectorA2 = selectors.contains {
            $0.className == "PRSExternalSystemService" &&
            $0.selectorName == "createLockScreenPhotosPosterWithImageAtURL:selectedLockScreenPoster:" &&
            $0.exists
        }

        if hasSelectorA1 {
            return (true, "createLockScreenPhotosPosterWithImageAtURL:selectLockScreenPoster:completion: is available")
        } else if hasSelectorA2 {
            return (true, "createLockScreenPhotosPosterWithImageAtURL:selectedLockScreenPoster: is available")
        } else {
            return (false, "Neither createLockScreenPhotosPosterWithImageAtURL variant is present on PRSExternalSystemService")
        }
    }

    private func evaluatePathB(
        classes: [ClassStatus],
        selectors: [SelectorStatus]
    ) -> (canAttempt: Bool, reason: String) {
        guard classes.first(where: { $0.name == "PRSService" && $0.exists }) != nil else {
            return (false, "PRSService class not found")
        }
        guard classes.first(where: { $0.name == "PRSPosterUpdate" && $0.exists }) != nil else {
            return (false, "PRSPosterUpdate class not found")
        }

        let hasCreate = selectors.contains {
            $0.className == "PRSService" &&
            $0.selectorName == "createPosterConfigurationForProviderIdentifier:posterDescriptorIdentifier:role:completion:" &&
            $0.exists
        }
        guard hasCreate else {
            return (false, "PRSService createPosterConfigurationForProviderIdentifier:... selector missing")
        }

        let hasUpdate = selectors.contains {
            $0.className == "PRSService" &&
            $0.selectorName == "updatePosterConfiguration:update:completion:" &&
            $0.exists
        }
        guard hasUpdate else {
            return (false, "PRSService updatePosterConfiguration:update:completion: selector missing")
        }

        let hasPosterUpdate = selectors.contains {
            $0.className == "PRSPosterUpdate" &&
            $0.selectorName == "posterUpdateLockScreenPosterWithImageAtURL:" &&
            $0.exists
        }
        guard hasPosterUpdate else {
            return (false, "PRSPosterUpdate posterUpdateLockScreenPosterWithImageAtURL: selector missing")
        }

        return (true, "PRSService creation/update and PRSPosterUpdate are fully present")
    }

    // MARK: - Host System Metadata

    private func currentOSVersion() -> String {
        #if canImport(UIKit)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion) (\(ProcessInfo.processInfo.operatingSystemVersionString))"
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    private func currentDarwinVersion() -> String {
        #if canImport(Darwin)
        if let kernOS = sysctlString(name: "kern.osversion") {
            return kernOS
        }
        #endif
        return "Unknown"
    }

    private func currentDeviceModel() -> String {
        // Attempt MobileGestalt lookup if available
        if let marketing = MGHelper.read(key: "marketing-name"), !marketing.isEmpty {
            if let product = MGHelper.read(key: "ProductType"), !product.isEmpty {
                return "\(marketing) (\(product))"
            }
            return marketing
        }

        #if canImport(Darwin)
        if let hwMachine = sysctlString(name: "hw.machine") {
            return hwMachine
        }
        #endif

        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "Generic Apple Device"
        #endif
    }

    #if canImport(Darwin)
    private func sysctlString(name: String) -> String? {
        var size: Int = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: size)
        let result = sysctlbyname(name, &buffer, &size, nil, 0)
        guard result == 0 else { return nil }

        return String(cString: buffer)
    }
    #endif
}
