//
//  WallpaperPosterInstaller.swift
//  Preferences
//
//  High-level, isolated facade for installing bundled or staged images
//  into Apple's PosterBoard system wallpaper service.
//

import Foundation
import ObjectiveC.runtime
#if canImport(UIKit)
import UIKit
#endif

/// Clean public facade for all private PosterBoard wallpaper installation operations.
public final class WallpaperPosterInstaller: @unchecked Sendable {
    public static let shared = WallpaperPosterInstaller()

    private let runtime = WallpaperPrivateRuntime.shared
    private let capabilitiesService = WallpaperPrivateCapabilities.shared
    private let stager = WallpaperImageStager.shared
    private let catalog = WallpaperCatalog.shared

    private init() {}

    // MARK: - Public Capabilities

    /// Returns the current runtime capabilities and execution readiness.
    public func capabilities() -> WallpaperRuntimeCapabilities {
        capabilitiesService.probe()
    }

    // MARK: - Public Installation API

    /// Installs a wallpaper from a local file URL into the system.
    ///
    /// - Parameters:
    ///   - imageURL: A readable local file URL pointing to an image.
    ///   - selectAfterCreation: If `true`, the newly installed poster configuration is selected as active.
    /// - Returns: A structured `WallpaperInstallResult`.
    public func addWallpaper(from imageURL: URL, selectAfterCreation: Bool = false) async throws -> WallpaperInstallResult {
        SettingsLogger.info("addWallpaper requested: url=\(imageURL.lastPathComponent), select=\(selectAfterCreation)")

        // 1. Stage the image into an app-controlled cache location
        let stagedURL = try stager.stageImage(from: imageURL)
        defer {
            // Keep staged file safe during async XPC; cleanup older files periodically
            stager.cleanupStaleFiles(olderThan: 3600)
        }

        // 2. Evaluate runtime capabilities
        let caps = capabilitiesService.probe()

        if caps.canAttemptPathA {
            SettingsLogger.info("Attempting installation via Path A (PRSExternalSystemService)")
            return try await executePathA(stagedURL: stagedURL, selectAfterCreation: selectAfterCreation)
        } else if caps.canAttemptPathB {
            SettingsLogger.info("Attempting installation via Path B (PRSService + PRSPosterUpdate)")
            return try await executePathB(stagedURL: stagedURL, selectAfterCreation: selectAfterCreation)
        } else {
            let reason = "Neither Path A nor Path B is available on this OS.\nPath A: \(caps.pathAAvailabilityReason)\nPath B: \(caps.pathBAvailabilityReason)"
            SettingsLogger.error(reason)
            throw WallpaperInstallError.unsupported(reason: reason)
        }
    }

    /// Installs a discovered bundled wallpaper.
    public func addBundledWallpaper(_ wallpaper: BundledWallpaper, selectAfterCreation: Bool = false) async throws -> WallpaperInstallResult {
        try await addWallpaper(from: wallpaper.url, selectAfterCreation: selectAfterCreation)
    }

    /// Generates the embedded test wallpaper and installs it.
    #if canImport(UIKit)
    @MainActor
    public func addTestWallpaper(selectAfterCreation: Bool = false) async throws -> WallpaperInstallResult {
        let testImageURL = try stager.stageGeneratedTestImage()
        return try await addWallpaper(from: testImageURL, selectAfterCreation: selectAfterCreation)
    }
    #endif

    // MARK: - Path A: PRSExternalSystemService

    private func executePathA(stagedURL: URL, selectAfterCreation: Bool) async throws -> WallpaperInstallResult {
        guard let serviceCls = runtime.resolveClass("PRSExternalSystemService") as? NSObject.Type else {
            throw WallpaperInstallError.classUnavailable(className: "PRSExternalSystemService")
        }

        // Obtain service instance
        let serviceSel = NSSelectorFromString("service")
        let serviceInstance: AnyObject
        if serviceCls.responds(to: serviceSel) {
            typealias ServiceGetter = @convention(c) (AnyClass, Selector) -> AnyObject?
            guard let method = class_getClassMethod(serviceCls, serviceSel) else {
                throw WallpaperInstallError.selectorUnavailable(className: "PRSExternalSystemService", selectorName: "service")
            }
            let imp = method_getImplementation(method)
            let getter = unsafeBitCast(imp, to: ServiceGetter.self)
            guard let instance = getter(serviceCls, serviceSel) else {
                throw WallpaperInstallError.systemServiceCallFailed(
                    domain: "Preferences.WallpaperPrivate",
                    code: -1,
                    message: "PRSExternalSystemService.service returned nil",
                    userInfo: [:]
                )
            }
            serviceInstance = instance
        } else {
            serviceInstance = serviceCls.init()
        }

        // Determine selector
        let selA1 = NSSelectorFromString("createLockScreenPhotosPosterWithImageAtURL:selectLockScreenPoster:completion:")
        let selA2 = NSSelectorFromString("createLockScreenPhotosPosterWithImageAtURL:selectedLockScreenPoster:")

        let targetSelector: Selector
        let hasCompletion: Bool

        if serviceCls.instancesRespond(to: selA1) {
            targetSelector = selA1
            hasCompletion = true
        } else if serviceCls.instancesRespond(to: selA2) {
            targetSelector = selA2
            hasCompletion = false
        } else {
            throw WallpaperInstallError.selectorUnavailable(
                className: "PRSExternalSystemService",
                selectorName: "createLockScreenPhotosPosterWithImageAtURL:selectLockScreenPoster:completion:"
            )
        }

        guard let targetMethod = class_getInstanceMethod(serviceCls, targetSelector) else {
            throw WallpaperInstallError.selectorUnavailable(
                className: "PRSExternalSystemService",
                selectorName: NSStringFromSelector(targetSelector)
            )
        }

        let imp = method_getImplementation(targetMethod)

        if hasCompletion {
            typealias CreatePosterWithCompletionFunc = @convention(c) (
                AnyObject,
                Selector,
                NSURL,
                ObjCBool,
                @convention(block) (AnyObject?, NSError?) -> Void
            ) -> Void

            let callable = unsafeBitCast(imp, to: CreatePosterWithCompletionFunc.self)

            return try await withCheckedThrowingContinuation { continuation in
                let completionBlock: @convention(block) (AnyObject?, NSError?) -> Void = { result, error in
                    if let error = error {
                        let details = self.mapNSError(error)
                        continuation.resume(throwing: WallpaperInstallError.systemServiceCallFailed(
                            domain: details.domain,
                            code: details.code,
                            message: details.message,
                            userInfo: details.userInfo
                        ))
                    } else {
                        let uuid = self.extractUUID(from: result)
                        let providerID = self.extractProviderBundleID(from: result)
                        let desc = result.map { String(describing: $0) }

                        let installResult = WallpaperInstallResult(
                            installPath: .pathA,
                            isSelected: selectAfterCreation,
                            serverUUID: uuid,
                            providerBundleIdentifier: providerID ?? WallpaperPrivateRuntime.photosProviderIdentifier,
                            rawConfigurationDescription: desc,
                            verifiedInSystemConfigurations: uuid != nil
                        )
                        continuation.resume(returning: installResult)
                    }
                }

                callable(
                    serviceInstance,
                    targetSelector,
                    stagedURL as NSURL,
                    ObjCBool(selectAfterCreation),
                    completionBlock
                )
            }
        } else {
            typealias CreatePosterWithoutCompletionFunc = @convention(c) (
                AnyObject,
                Selector,
                NSURL,
                ObjCBool
            ) -> AnyObject?

            let callable = unsafeBitCast(imp, to: CreatePosterWithoutCompletionFunc.self)
            let result = callable(serviceInstance, targetSelector, stagedURL as NSURL, ObjCBool(selectAfterCreation))

            let uuid = extractUUID(from: result)
            let providerID = extractProviderBundleID(from: result)

            return WallpaperInstallResult(
                installPath: .pathA,
                isSelected: selectAfterCreation,
                serverUUID: uuid,
                providerBundleIdentifier: providerID ?? WallpaperPrivateRuntime.photosProviderIdentifier,
                rawConfigurationDescription: result.map { String(describing: $0) },
                verifiedInSystemConfigurations: uuid != nil
            )
        }
    }

    // MARK: - Path B: PRSService + PRSPosterUpdate

    private func executePathB(stagedURL: URL, selectAfterCreation: Bool) async throws -> WallpaperInstallResult {
        guard let prsCls = runtime.resolveClass("PRSService") as? NSObject.Type else {
            throw WallpaperInstallError.classUnavailable(className: "PRSService")
        }
        guard let updateCls = runtime.resolveClass("PRSPosterUpdate") else {
            throw WallpaperInstallError.classUnavailable(className: "PRSPosterUpdate")
        }

        // Step B1: Obtain PRSService instance
        let prsService = try resolvePRSServiceInstance(prsCls: prsCls)

        // Step B2: Create poster configuration for Photos provider
        let createSel = NSSelectorFromString("createPosterConfigurationForProviderIdentifier:posterDescriptorIdentifier:role:completion:")
        guard let createMethod = class_getInstanceMethod(prsCls, createSel) else {
            throw WallpaperInstallError.selectorUnavailable(
                className: "PRSService",
                selectorName: "createPosterConfigurationForProviderIdentifier:posterDescriptorIdentifier:role:completion:"
            )
        }

        typealias CreateConfigFunc = @convention(c) (
            AnyObject,
            Selector,
            NSString,
            NSString?,
            NSString,
            @convention(block) (AnyObject?, NSError?) -> Void
        ) -> Void

        let createCallable = unsafeBitCast(method_getImplementation(createMethod), to: CreateConfigFunc.self)

        let initialConfig: AnyObject = try await withCheckedThrowingContinuation { continuation in
            let completionBlock: @convention(block) (AnyObject?, NSError?) -> Void = { config, error in
                if let error = error {
                    let details = self.mapNSError(error)
                    continuation.resume(throwing: WallpaperInstallError.systemServiceCallFailed(
                        domain: details.domain,
                        code: details.code,
                        message: details.message,
                        userInfo: details.userInfo
                    ))
                } else if let config = config {
                    continuation.resume(returning: config)
                } else {
                    continuation.resume(throwing: WallpaperInstallError.systemServiceCallFailed(
                        domain: "Preferences.WallpaperPrivate",
                        code: -2,
                        message: "createPosterConfiguration completed with nil configuration and nil error",
                        userInfo: [:]
                    ))
                }
            }

            createCallable(
                prsService,
                createSel,
                WallpaperPrivateRuntime.photosProviderIdentifier as NSString,
                nil,
                WallpaperPrivateRuntime.lockScreenRole as NSString,
                completionBlock
            )
        }

        SettingsLogger.info("Created preliminary poster configuration: \(String(describing: initialConfig))")

        // Step B3: Instantiate PRSPosterUpdate
        let updateSel = NSSelectorFromString("posterUpdateLockScreenPosterWithImageAtURL:")
        guard let metaUpdateCls = object_getClass(updateCls),
              let posterUpdateMethod = class_getInstanceMethod(metaUpdateCls, updateSel) ?? class_getClassMethod(updateCls, updateSel) else {
            let cleanup = await cleanupOrphanConfiguration(initialConfig, prsService: prsService)
            throw WallpaperInstallError.posterUpdateFailed(
                domain: "Preferences.WallpaperPrivate",
                code: -3,
                message: "PRSPosterUpdate posterUpdateLockScreenPosterWithImageAtURL: selector unavailable",
                cleanupAttempted: cleanup.attempted,
                cleanupSucceeded: cleanup.succeeded,
                userInfo: [:]
            )
        }

        typealias PosterUpdateFactoryFunc = @convention(c) (
            AnyClass,
            Selector,
            NSURL
        ) -> AnyObject?

        let updateFactory = unsafeBitCast(method_getImplementation(posterUpdateMethod), to: PosterUpdateFactoryFunc.self)
        guard let posterUpdate = updateFactory(updateCls, updateSel, stagedURL as NSURL) else {
            let cleanup = await cleanupOrphanConfiguration(initialConfig, prsService: prsService)
            throw WallpaperInstallError.posterUpdateFailed(
                domain: "Preferences.WallpaperPrivate",
                code: -4,
                message: "posterUpdateLockScreenPosterWithImageAtURL returned nil",
                cleanupAttempted: cleanup.attempted,
                cleanupSucceeded: cleanup.succeeded,
                userInfo: [:]
            )
        }

        // Step B4: Update poster configuration with image
        let updateConfigSel = NSSelectorFromString("updatePosterConfiguration:update:completion:")
        guard let updateConfigMethod = class_getInstanceMethod(prsCls, updateConfigSel) else {
            let cleanup = await cleanupOrphanConfiguration(initialConfig, prsService: prsService)
            throw WallpaperInstallError.posterUpdateFailed(
                domain: "Preferences.WallpaperPrivate",
                code: -5,
                message: "PRSService updatePosterConfiguration:update:completion: selector unavailable",
                cleanupAttempted: cleanup.attempted,
                cleanupSucceeded: cleanup.succeeded,
                userInfo: [:]
            )
        }

        typealias UpdateConfigFunc = @convention(c) (
            AnyObject,
            Selector,
            AnyObject,
            AnyObject,
            @convention(block) (AnyObject?, NSError?) -> Void
        ) -> Void

        let updateConfigCallable = unsafeBitCast(method_getImplementation(updateConfigMethod), to: UpdateConfigFunc.self)

        let updatedConfig: AnyObject = try await withCheckedThrowingContinuation { continuation in
            let completionBlock: @convention(block) (AnyObject?, NSError?) -> Void = { result, error in
                if let error = error {
                    let details = self.mapNSError(error)
                    continuation.resume(throwing: WallpaperInstallError.posterUpdateFailed(
                        domain: details.domain,
                        code: details.code,
                        message: details.message,
                        cleanupAttempted: false,
                        cleanupSucceeded: false,
                        userInfo: details.userInfo
                    ))
                } else if let result = result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(returning: initialConfig)
                }
            }

            updateConfigCallable(
                prsService,
                updateConfigSel,
                initialConfig,
                posterUpdate,
                completionBlock
            )
        }

        SettingsLogger.info("Updated poster configuration with image: \(String(describing: updatedConfig))")

        // Step B5: If Add & Use requested, update active role selection
        if selectAfterCreation {
            let selectSel = NSSelectorFromString("updateSelectedForRoleIdentifier:newlySelectedConfiguration:completion:")
            if prsCls.instancesRespond(to: selectSel),
               let selectMethod = class_getInstanceMethod(prsCls, selectSel) {
                typealias SelectRoleFunc = @convention(c) (
                    AnyObject,
                    Selector,
                    NSString,
                    AnyObject,
                    @convention(block) (AnyObject?, NSError?) -> Void
                ) -> Void

                let selectCallable = unsafeBitCast(method_getImplementation(selectMethod), to: SelectRoleFunc.self)

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    let completionBlock: @convention(block) (AnyObject?, NSError?) -> Void = { _, error in
                        if let error = error {
                            let details = self.mapNSError(error)
                            continuation.resume(throwing: WallpaperInstallError.roleSelectionFailed(
                                domain: details.domain,
                                code: details.code,
                                message: details.message,
                                userInfo: details.userInfo
                            ))
                        } else {
                            continuation.resume(returning: ())
                        }
                    }

                    selectCallable(
                        prsService,
                        selectSel,
                        WallpaperPrivateRuntime.lockScreenRole as NSString,
                        updatedConfig,
                        completionBlock
                    )
                }
                SettingsLogger.info("Selected newly created poster configuration for lock screen role")
            } else {
                SettingsLogger.error("updateSelectedForRoleIdentifier selector unavailable on PRSService")
            }
        }

        // Step B6: Verify configuration in system
        let serverUUID = extractUUID(from: updatedConfig) ?? extractUUID(from: initialConfig)
        let providerID = extractProviderBundleID(from: updatedConfig) ?? WallpaperPrivateRuntime.photosProviderIdentifier

        return WallpaperInstallResult(
            installPath: .pathB,
            isSelected: selectAfterCreation,
            serverUUID: serverUUID,
            providerBundleIdentifier: providerID,
            rawConfigurationDescription: String(describing: updatedConfig),
            verifiedInSystemConfigurations: serverUUID != nil
        )
    }

    // MARK: - Cleanup On Partial Failure

    private func cleanupOrphanConfiguration(_ config: AnyObject, prsService: AnyObject) async -> (attempted: Bool, succeeded: Bool) {
        guard let prsCls = runtime.resolveClass("PRSService") else { return (false, false) }
        let deleteSel = NSSelectorFromString("deletePosterConfigurationsMatchingUUID:completion:")
        guard prsCls.instancesRespond(to: deleteSel),
              let deleteMethod = class_getInstanceMethod(prsCls, deleteSel) else {
            return (false, false)
        }

        guard let uuid = extractUUID(from: config) else {
            return (false, false)
        }

        let nsuuid = uuid as NSUUID

        typealias DeleteFunc = @convention(c) (
            AnyObject,
            Selector,
            AnyObject,
            @convention(block) (AnyObject?, NSError?) -> Void
        ) -> Void

        let callable = unsafeBitCast(method_getImplementation(deleteMethod), to: DeleteFunc.self)

        return await withCheckedContinuation { continuation in
            callable(prsService, deleteSel, nsuuid) { _, error in
                let succeeded = (error == nil)
                SettingsLogger.info("Cleanup of orphan poster configuration \(uuid) succeeded=\(succeeded)")
                continuation.resume(returning: (true, succeeded))
            }
        }
    }

    // MARK: - Verification / Inspection

    /// Fetches all installed poster summaries for the Lock Screen role.
    public func fetchInstalledLockScreenPosterConfigurations() async -> [InstalledPosterSummary] {
        guard let prsCls = runtime.resolveClass("PRSService") as? NSObject.Type,
              let prsService = try? resolvePRSServiceInstance(prsCls: prsCls) else {
            return []
        }

        let fetchSel = NSSelectorFromString("fetchPosterConfigurationsForRole:completion:")
        guard prsCls.instancesRespond(to: fetchSel),
              let fetchMethod = class_getInstanceMethod(prsCls, fetchSel) else {
            return []
        }

        typealias FetchFunc = @convention(c) (
            AnyObject,
            Selector,
            NSString,
            @convention(block) (NSArray?, NSError?) -> Void
        ) -> Void

        let callable = unsafeBitCast(method_getImplementation(fetchMethod), to: FetchFunc.self)

        return await withCheckedContinuation { continuation in
            callable(prsService, fetchSel, WallpaperPrivateRuntime.lockScreenRole as NSString) { array, error in
                guard error == nil, let list = array as? [AnyObject] else {
                    continuation.resume(returning: [])
                    return
                }

                let summaries = list.map { item in
                    let uuid = self.extractUUID(from: item)
                    let provider = self.extractProviderBundleID(from: item)
                    let desc = (item as? NSObject)?.value(forKey: "descriptorIdentifier") as? String
                    return InstalledPosterSummary(
                        serverUUID: uuid,
                        providerBundleIdentifier: provider,
                        descriptorIdentifier: desc,
                        rawDescription: String(describing: item)
                    )
                }
                continuation.resume(returning: summaries)
            }
        }
    }

    // MARK: - Helpers

    private func resolvePRSServiceInstance(prsCls: NSObject.Type) throws -> AnyObject {
        let serviceSel = NSSelectorFromString("service")
        if prsCls.responds(to: serviceSel),
           let method = class_getClassMethod(prsCls, serviceSel) {
            typealias Getter = @convention(c) (AnyClass, Selector) -> AnyObject?
            let getter = unsafeBitCast(method_getImplementation(method), to: Getter.self)
            if let instance = getter(prsCls, serviceSel) {
                return instance
            }
        }

        let sharedSel = NSSelectorFromString("sharedInstance")
        if prsCls.responds(to: sharedSel),
           let method = class_getClassMethod(prsCls, sharedSel) {
            typealias Getter = @convention(c) (AnyClass, Selector) -> AnyObject?
            let getter = unsafeBitCast(method_getImplementation(method), to: Getter.self)
            if let instance = getter(prsCls, sharedSel) {
                return instance
            }
        }

        return prsCls.init()
    }

    private func extractUUID(from object: AnyObject?) -> UUID? {
        guard let obj = object else { return nil }

        if let directUUID = (obj as? NSObject)?.value(forKey: "serverUUID") as? UUID {
            return directUUID
        }
        if let nsUUID = (obj as? NSObject)?.value(forKey: "serverUUID") as? NSUUID {
            return nsUUID as UUID
        }
        if let stringUUID = (obj as? NSObject)?.value(forKey: "serverUUID") as? String,
           let parsed = UUID(uuidString: stringUUID) {
            return parsed
        }

        let sel = NSSelectorFromString("serverUUID")
        if obj.responds(to: sel) {
            if let val = obj.perform(sel)?.takeUnretainedValue() {
                if let direct = val as? UUID { return direct }
                if let ns = val as? NSUUID { return ns as UUID }
                if let str = val as? String { return UUID(uuidString: str) }
            }
        }
        return nil
    }

    private func extractProviderBundleID(from object: AnyObject?) -> String? {
        guard let obj = object else { return nil }

        if let direct = (obj as? NSObject)?.value(forKey: "providerBundleIdentifier") as? String {
            return direct
        }

        let sel = NSSelectorFromString("providerBundleIdentifier")
        if obj.responds(to: sel),
           let val = obj.perform(sel)?.takeUnretainedValue() as? String {
            return val
        }
        return nil
    }

    private func mapNSError(_ error: NSError) -> (domain: String, code: Int, message: String, userInfo: [String: String]) {
        var dict: [String: String] = [:]
        for (k, v) in error.userInfo {
            dict[String(describing: k)] = String(describing: v)
        }
        return (error.domain, error.code, error.localizedDescription, dict)
    }
}
