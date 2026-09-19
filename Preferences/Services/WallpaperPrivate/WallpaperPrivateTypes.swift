//
//  WallpaperPrivateTypes.swift
//  Preferences
//
//  Data types, results, errors, and capability models for the private
//  PosterBoard wallpaper integration layer.
//

import Foundation

/// Represents a wallpaper bundled inside the app's resources.
public struct BundledWallpaper: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let url: URL
    public let fileSize: Int64
    
    public init(id: String, name: String, url: URL, fileSize: Int64 = 0) {
        self.id = id
        self.name = name
        self.url = url
        self.fileSize = fileSize
    }
}

/// The installation strategy used to register a wallpaper poster configuration.
public enum WallpaperInstallPath: String, Sendable, CaseIterable {
    case pathA = "Path A (PRSExternalSystemService)"
    case pathB = "Path B (PRSService + PRSPosterUpdate)"
}

/// The structured result of a wallpaper installation attempt.
public struct WallpaperInstallResult: Sendable {
    public let installPath: WallpaperInstallPath
    public let isSelected: Bool
    public let serverUUID: UUID?
    public let providerBundleIdentifier: String?
    public let rawConfigurationDescription: String?
    public let verifiedInSystemConfigurations: Bool
    public let timestamp: Date

    public init(
        installPath: WallpaperInstallPath,
        isSelected: Bool,
        serverUUID: UUID?,
        providerBundleIdentifier: String?,
        rawConfigurationDescription: String?,
        verifiedInSystemConfigurations: Bool,
        timestamp: Date = Date()
    ) {
        self.installPath = installPath
        self.isSelected = isSelected
        self.serverUUID = serverUUID
        self.providerBundleIdentifier = providerBundleIdentifier
        self.rawConfigurationDescription = rawConfigurationDescription
        self.verifiedInSystemConfigurations = verifiedInSystemConfigurations
        self.timestamp = timestamp
    }
}

/// Typed, actionable errors for the private wallpaper installation pipeline.
public enum WallpaperInstallError: LocalizedError, Sendable {
    case frameworkUnavailable(frameworkName: String, path: String, reason: String?)
    case classUnavailable(className: String)
    case selectorUnavailable(className: String, selectorName: String)
    case imageStagingFailed(reason: String)
    case systemServiceCallFailed(domain: String, code: Int, message: String, userInfo: [String: String])
    case posterUpdateFailed(domain: String, code: Int, message: String, cleanupAttempted: Bool, cleanupSucceeded: Bool, userInfo: [String: String])
    case roleSelectionFailed(domain: String, code: Int, message: String, userInfo: [String: String])
    case unsupported(reason: String)

    public var errorDescription: String? {
        switch self {
        case .frameworkUnavailable(let name, let path, let reason):
            return "Private framework '\(name)' could not be loaded from '\(path)'. Reason: \(reason ?? "unknown")"
        case .classUnavailable(let cls):
            return "Private class '\(cls)' was not found at runtime."
        case .selectorUnavailable(let cls, let sel):
            return "Selector '\(sel)' was not found on class '\(cls)'."
        case .imageStagingFailed(let reason):
            return "Failed to stage image: \(reason)"
        case .systemServiceCallFailed(let domain, let code, let message, _):
            return "Poster system service call failed [\(domain):\(code)]: \(message)"
        case .posterUpdateFailed(let domain, let code, let message, let cleanupAttempted, let cleanupSucceeded, _):
            let cleanupNote = cleanupAttempted ? (cleanupSucceeded ? " (Orphan configuration cleaned up)" : " (Cleanup failed)") : ""
            return "Poster update failed [\(domain):\(code)]: \(message)\(cleanupNote)"
        case .roleSelectionFailed(let domain, let code, let message, _):
            return "Poster role selection failed [\(domain):\(code)]: \(message)"
        case .unsupported(let reason):
            return "Wallpaper installation unsupported: \(reason)"
        }
    }

    public var failureDetails: (domain: String, code: Int, message: String, userInfo: [String: String])? {
        switch self {
        case .systemServiceCallFailed(let domain, let code, let message, let userInfo):
            return (domain, code, message, userInfo)
        case .posterUpdateFailed(let domain, let code, let message, _, _, let userInfo):
            return (domain, code, message, userInfo)
        case .roleSelectionFailed(let domain, let code, let message, let userInfo):
            return (domain, code, message, userInfo)
        default:
            return nil
        }
    }
}

/// Status of a dynamic private framework load.
public struct FrameworkStatus: Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let path: String
    public let isLoaded: Bool
    public let dlerrorString: String?

    public init(name: String, path: String, isLoaded: Bool, dlerrorString: String? = nil) {
        self.name = name
        self.path = path
        self.isLoaded = isLoaded
        self.dlerrorString = dlerrorString
    }
}

/// Status of a private class probe.
public struct ClassStatus: Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let exists: Bool

    public init(name: String, exists: Bool) {
        self.name = name
        self.exists = exists
    }
}

/// Status of an Objective-C selector probe.
public struct SelectorStatus: Sendable, Identifiable {
    public var id: String { "\(className).\(selectorName)[\(isClassMethod ? "+" : "-")]" }
    public let className: String
    public let selectorName: String
    public let isClassMethod: Bool
    public let exists: Bool
    public let typeEncoding: String?
    public let argumentCount: Int?

    public init(
        className: String,
        selectorName: String,
        isClassMethod: Bool,
        exists: Bool,
        typeEncoding: String? = nil,
        argumentCount: Int? = nil
    ) {
        self.className = className
        self.selectorName = selectorName
        self.isClassMethod = isClassMethod
        self.exists = exists
        self.typeEncoding = typeEncoding
        self.argumentCount = argumentCount
    }
}

/// Represents an Objective-C method discovered at runtime via reflection.
public struct DiscoveredSelector: Sendable, Identifiable {
    public var id: String { "\(className).\(selectorName)[\(isClassMethod ? "+" : "-")]" }
    public let className: String
    public let selectorName: String
    public let isClassMethod: Bool
    public let typeEncoding: String?
    public let argumentCount: Int?

    public init(
        className: String,
        selectorName: String,
        isClassMethod: Bool,
        typeEncoding: String?,
        argumentCount: Int?
    ) {
        self.className = className
        self.selectorName = selectorName
        self.isClassMethod = isClassMethod
        self.typeEncoding = typeEncoding
        self.argumentCount = argumentCount
    }
}

/// High-level summary of an installed system poster configuration.
public struct InstalledPosterSummary: Sendable, Identifiable {
    public var id: String { serverUUID?.uuidString ?? rawDescription }
    public let serverUUID: UUID?
    public let providerBundleIdentifier: String?
    public let descriptorIdentifier: String?
    public let rawDescription: String

    public init(
        serverUUID: UUID?,
        providerBundleIdentifier: String?,
        descriptorIdentifier: String?,
        rawDescription: String
    ) {
        self.serverUUID = serverUUID
        self.providerBundleIdentifier = providerBundleIdentifier
        self.descriptorIdentifier = descriptorIdentifier
        self.rawDescription = rawDescription
    }
}

/// Comprehensive report of the runtime environment and private PosterBoard capabilities.
public struct WallpaperRuntimeCapabilities: Sendable {
    public let osVersion: String
    public let darwinVersion: String
    public let deviceModel: String
    public let frameworks: [FrameworkStatus]
    public let classes: [ClassStatus]
    public let knownSelectors: [SelectorStatus]
    public let discoveredSelectors: [DiscoveredSelector]
    public let canAttemptPathA: Bool
    public let canAttemptPathB: Bool
    public let pathAAvailabilityReason: String
    public let pathBAvailabilityReason: String
    public let generatedAt: Date

    public init(
        osVersion: String,
        darwinVersion: String,
        deviceModel: String,
        frameworks: [FrameworkStatus],
        classes: [ClassStatus],
        knownSelectors: [SelectorStatus],
        discoveredSelectors: [DiscoveredSelector],
        canAttemptPathA: Bool,
        canAttemptPathB: Bool,
        pathAAvailabilityReason: String,
        pathBAvailabilityReason: String,
        generatedAt: Date = Date()
    ) {
        self.osVersion = osVersion
        self.darwinVersion = darwinVersion
        self.deviceModel = deviceModel
        self.frameworks = frameworks
        self.classes = classes
        self.knownSelectors = knownSelectors
        self.discoveredSelectors = discoveredSelectors
        self.canAttemptPathA = canAttemptPathA
        self.canAttemptPathB = canAttemptPathB
        self.pathAAvailabilityReason = pathAAvailabilityReason
        self.pathBAvailabilityReason = pathBAvailabilityReason
        self.generatedAt = generatedAt
    }

    /// Generates a structured markdown report suitable for diagnostics or clipboard export.
    public func formattedReport() -> String {
        var report = """
        # PosterBoard Private Runtime Diagnostic Report
        Generated: \(ISO8601DateFormatter().string(from: generatedAt))

        ## System Environment
        - OS Version: \(osVersion)
        - Darwin / Build (kern.osversion): \(darwinVersion)
        - Device Model: \(deviceModel)

        ## Execution Path Evaluation
        - Path A (PRSExternalSystemService direct): \(canAttemptPathA ? "AVAILABLE" : "UNAVAILABLE") (\(pathAAvailabilityReason))
        - Path B (PRSService + PRSPosterUpdate fallback): \(canAttemptPathB ? "AVAILABLE" : "UNAVAILABLE") (\(pathBAvailabilityReason))

        ## Private Frameworks
        """

        for fw in frameworks {
            let status = fw.isLoaded ? "LOADED" : "FAILED"
            let errStr = fw.dlerrorString != nil ? " (Error: \(fw.dlerrorString!))" : ""
            report += "\n- `\(fw.name)`: \(status)\(errStr)\n  Path: `\(fw.path)`"
        }

        report += "\n\n## Key Classes"
        for cls in classes {
            report += "\n- `\(cls.name)`: \(cls.exists ? "EXISTS" : "NOT FOUND")"
        }

        report += "\n\n## Known Selectors Probed"
        for sel in knownSelectors {
            let kind = sel.isClassMethod ? "+" : "-"
            let status = sel.exists ? "FOUND" : "MISSING"
            let encodingStr = sel.typeEncoding.map { " [\( $0 )]" } ?? ""
            let argsStr = sel.argumentCount.map { " (args: \( $0 ))" } ?? ""
            report += "\n- `\(kind)[\(sel.className) \(sel.selectorName)]`: \(status)\(encodingStr)\(argsStr)"
        }

        report += "\n\n## Discovered Related Selectors (\(discoveredSelectors.count) matches)"
        if discoveredSelectors.isEmpty {
            report += "\n(No related selectors discovered)"
        } else {
            for sel in discoveredSelectors {
                let kind = sel.isClassMethod ? "+" : "-"
                let encodingStr = sel.typeEncoding.map { " [\( $0 )]" } ?? ""
                let argsStr = sel.argumentCount.map { " (args: \( $0 ))" } ?? ""
                report += "\n- `\(kind)[\(sel.className) \(sel.selectorName)]`\(encodingStr)\(argsStr)"
            }
        }

        return report
    }
}
