//
//  WallpaperPrivateRuntime.swift
//  Preferences
//
//  Dynamic runtime loader, introspection, and probing for private
//  PosterBoard and Photos frameworks.
//

import Foundation
import ObjectiveC.runtime
#if canImport(Darwin)
import Darwin
#endif

/// Handles dynamic loading and introspection of Apple's private PosterBoard frameworks.
public final class WallpaperPrivateRuntime: @unchecked Sendable {
    public static let shared = WallpaperPrivateRuntime()

    // MARK: - Constants

    public static let posterBoardServicesPath = "/System/Library/PrivateFrameworks/PosterBoardServices.framework/PosterBoardServices"
    public static let photosFormatsPath = "/System/Library/PrivateFrameworks/PhotosFormats.framework/PhotosFormats"
    public static let photosUIPrivatePath = "/System/Library/PrivateFrameworks/PhotosUIPrivate.framework/PhotosUIPrivate"

    public static let photosProviderIdentifier = "com.apple.PhotosUIPrivate.PhotosPosterProvider"
    public static let lockScreenRole = "PRPosterRoleLockScreen"

    // MARK: - Probing Data Structures

    private struct TargetSelector {
        let className: String
        let selectorName: String
        let isClassMethod: Bool
    }

    private let targetFrameworks: [(name: String, path: String)] = [
        ("PosterBoardServices", posterBoardServicesPath),
        ("PhotosFormats", photosFormatsPath),
        ("PhotosUIPrivate", photosUIPrivatePath)
    ]

    private let targetClasses: [String] = [
        "PRSExternalSystemService",
        "PRSService",
        "PRSPosterUpdate",
        "PFPosterMediaURLImage",
        "PUWallpaperPosterEditorController"
    ]

    private let targetSelectors: [TargetSelector] = [
        // PRSExternalSystemService
        TargetSelector(className: "PRSExternalSystemService", selectorName: "service", isClassMethod: true),
        TargetSelector(className: "PRSExternalSystemService", selectorName: "createLockScreenPhotosPosterWithImageAtURL:selectLockScreenPoster:completion:", isClassMethod: false),
        TargetSelector(className: "PRSExternalSystemService", selectorName: "createLockScreenPhotosPosterWithImageAtURL:selectedLockScreenPoster:", isClassMethod: false),
        TargetSelector(className: "PRSExternalSystemService", selectorName: "updateLockScreenPhotosPoster:withImageAtURL:selectLockScreenPoster:completion:", isClassMethod: false),
        TargetSelector(className: "PRSExternalSystemService", selectorName: "fetchEligibleConfigurationsWithCompletion:", isClassMethod: false),

        // PRSService
        TargetSelector(className: "PRSService", selectorName: "service", isClassMethod: true),
        TargetSelector(className: "PRSService", selectorName: "sharedInstance", isClassMethod: true),
        TargetSelector(className: "PRSService", selectorName: "createPosterConfigurationForProviderIdentifier:posterDescriptorIdentifier:role:completion:", isClassMethod: false),
        TargetSelector(className: "PRSService", selectorName: "updatePosterConfiguration:update:completion:", isClassMethod: false),
        TargetSelector(className: "PRSService", selectorName: "updateSelectedForRoleIdentifier:newlySelectedConfiguration:completion:", isClassMethod: false),
        TargetSelector(className: "PRSService", selectorName: "deletePosterConfigurationsMatchingUUID:completion:", isClassMethod: false),
        TargetSelector(className: "PRSService", selectorName: "fetchPosterConfigurationsForRole:completion:", isClassMethod: false),

        // PRSPosterUpdate
        TargetSelector(className: "PRSPosterUpdate", selectorName: "posterUpdateLockScreenPosterWithImageAtURL:", isClassMethod: true),
        TargetSelector(className: "PRSPosterUpdate", selectorName: "posterUpdateHomeScreenPosterWithImageAtURL:", isClassMethod: true),

        // PFPosterMediaURLImage
        TargetSelector(className: "PFPosterMediaURLImage", selectorName: "initWithImageAtURL:", isClassMethod: false),

        // PUWallpaperPosterEditorController
        TargetSelector(className: "PUWallpaperPosterEditorController", selectorName: "_loadImagePosterMedia:", isClassMethod: false),
        TargetSelector(className: "PUWallpaperPosterEditorController", selectorName: "_loadAssetPosterMedia:", isClassMethod: false),
        TargetSelector(className: "PUWallpaperPosterEditorController", selectorName: "_loadContentForCurrentPosterMedia", isClassMethod: false)
    ]

    private let discoveryKeywords = [
        "wallpaper", "poster", "photo", "image", "url", "configuration", "create", "update", "gallery"
    ]

    // MARK: - State

    private let lock = NSLock()
    private var loadedHandles: [String: UnsafeMutableRawPointer] = [:]

    private init() {}

    deinit {
        lock.lock()
        defer { lock.unlock() }
        #if canImport(Darwin)
        for (_, handle) in loadedHandles {
            dlclose(handle)
        }
        #endif
        loadedHandles.removeAll()
    }

    // MARK: - Framework Loading

    /// Dynamically loads a private framework if available, caching the handle.
    @discardableResult
    public func loadFramework(path: String) -> (isLoaded: Bool, error: String?) {
        lock.lock()
        defer { lock.unlock() }

        #if canImport(Darwin)
        if loadedHandles[path] != nil {
            return (true, nil)
        }

        guard let handle = dlopen(path, RTLD_NOW) else {
            let errorMsg = dlerror().map { String(cString: $0) }
            return (false, errorMsg)
        }

        loadedHandles[path] = handle
        return (true, nil)
        #else
        return (false, "dlopen is only supported on Darwin platforms")
        #endif
    }

    /// Loads all known target private frameworks.
    public func loadAllTargetFrameworks() -> [FrameworkStatus] {
        targetFrameworks.map { item in
            let result = loadFramework(path: item.path)
            return FrameworkStatus(
                name: item.name,
                path: item.path,
                isLoaded: result.isLoaded,
                dlerrorString: result.error
            )
        }
    }

    // MARK: - Introspection

    /// Probes availability of a class by name after ensuring target frameworks are loaded.
    public func probeClass(named className: String) -> ClassStatus {
        let cls: AnyClass? = NSClassFromString(className)
        return ClassStatus(name: className, exists: cls != nil)
    }

    /// Resolves an `AnyClass` safely.
    public func resolveClass(_ className: String) -> AnyClass? {
        NSClassFromString(className)
    }

    /// Probes a specific selector on a class.
    public func probeSelector(className: String, selectorName: String, isClassMethod: Bool) -> SelectorStatus {
        guard let cls = NSClassFromString(className) else {
            return SelectorStatus(
                className: className,
                selectorName: selectorName,
                isClassMethod: isClassMethod,
                exists: false
            )
        }

        let sel = NSSelectorFromString(selectorName)
        let method: Method?

        if isClassMethod {
            guard let metaCls = object_getClass(cls) else {
                return SelectorStatus(className: className, selectorName: selectorName, isClassMethod: true, exists: false)
            }
            method = class_getInstanceMethod(metaCls, sel) ?? class_getClassMethod(cls, sel)
        } else {
            method = class_getInstanceMethod(cls, sel)
        }

        guard let foundMethod = method else {
            return SelectorStatus(
                className: className,
                selectorName: selectorName,
                isClassMethod: isClassMethod,
                exists: false
            )
        }

        let encoding: String?
        if let typeCString = method_getTypeEncoding(foundMethod) {
            encoding = String(cString: typeCString)
        } else {
            encoding = nil
        }

        let argCount = Int(method_getNumberOfArguments(foundMethod))

        return SelectorStatus(
            className: className,
            selectorName: selectorName,
            isClassMethod: isClassMethod,
            exists: true,
            typeEncoding: encoding,
            argumentCount: argCount
        )
    }

    /// Discovers candidate methods on relevant classes whose names match wallpaper-related keywords.
    public func discoverRelatedSelectors() -> [DiscoveredSelector] {
        var results: [DiscoveredSelector] = []
        var seen = Set<String>()

        for className in targetClasses {
            guard let cls = NSClassFromString(className) else { continue }

            // 1. Instance methods
            let instanceMethods = copyMethods(for: cls, isClassMethod: false, className: className)
            for m in instanceMethods {
                let key = "\(className).\(m.selectorName)[-]"
                if !seen.contains(key), matchesKeyword(m.selectorName) {
                    seen.insert(key)
                    results.append(m)
                }
            }

            // 2. Class methods
            if let metaCls = object_getClass(cls) {
                let classMethods = copyMethods(for: metaCls, isClassMethod: true, className: className)
                for m in classMethods {
                    let key = "\(className).\(m.selectorName)[+]"
                    if !seen.contains(key), matchesKeyword(m.selectorName) {
                        seen.insert(key)
                        results.append(m)
                    }
                }
            }
        }

        return results.sorted { $0.id < $1.id }
    }

    private func copyMethods(for aClass: AnyClass, isClassMethod: Bool, className: String) -> [DiscoveredSelector] {
        var count: UInt32 = 0
        guard let methodList = class_copyMethodList(aClass, &count) else { return [] }
        defer { free(methodList) }

        var list: [DiscoveredSelector] = []
        for i in 0..<Int(count) {
            let method = methodList[i]
            let sel = method_getName(method)
            let selName = NSStringFromSelector(sel)
            let encoding = method_getTypeEncoding(method).map { String(cString: $0) }
            let args = Int(method_getNumberOfArguments(method))

            list.append(DiscoveredSelector(
                className: className,
                selectorName: selName,
                isClassMethod: isClassMethod,
                typeEncoding: encoding,
                argumentCount: args
            ))
        }
        return list
    }

    private func matchesKeyword(_ name: String) -> Bool {
        let lower = name.lowercased()
        return discoveryKeywords.contains { lower.contains($0) }
    }

    // MARK: - Complete Diagnostic Probe

    /// Performs a full runtime probe of frameworks, classes, known selectors, and discovered selectors.
    public func executeFullProbe() -> (
        frameworks: [FrameworkStatus],
        classes: [ClassStatus],
        selectors: [SelectorStatus],
        discovered: [DiscoveredSelector]
    ) {
        let fws = loadAllTargetFrameworks()
        let classes = targetClasses.map { probeClass(named: $0) }
        let selectors = targetSelectors.map {
            probeSelector(className: $0.className, selectorName: $0.selectorName, isClassMethod: $0.isClassMethod)
        }
        let discovered = discoverRelatedSelectors()

        return (fws, classes, selectors, discovered)
    }
}
