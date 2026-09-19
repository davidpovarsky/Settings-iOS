//
//  WallpaperPosterUIBridge.swift
//  Preferences
//
//  Isolated dynamic bridge for Apple UI-hosted wallpaper flows:
//  1. PosterBoardUIServices (PRUISModalEntryPointGallery + PRUISModalController)
//  2. SpringBoardUIServices (SBSUIWallpaperPreviewViewController)
//

import Foundation
import ObjectiveC.runtime
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Darwin)
import Darwin
#endif

/// Clean Swift facade for presenting Apple-hosted wallpaper UI components out-of-process.
@MainActor
public final class WallpaperPosterUIBridge {
    public static let shared = WallpaperPosterUIBridge()

    // MARK: - Framework Paths

    public static let posterBoardUIServicesPath = "/System/Library/PrivateFrameworks/PosterBoardUIServices.framework/PosterBoardUIServices"
    public static let springBoardUIServicesPath = "/System/Library/PrivateFrameworks/SpringBoardUIServices.framework/SpringBoardUIServices"

    // MARK: - State Retention

    /// Strongly retained modal controller to prevent deallocation during presentation.
    private var activeModalController: AnyObject?

    private init() {}

    // MARK: - Framework Loading

    /// Loads PosterBoardUIServices and SpringBoardUIServices dynamically.
    public func ensureFrameworksLoaded() {
        let runtime = WallpaperPrivateRuntime.shared
        _ = runtime.loadFramework(path: Self.posterBoardUIServicesPath)
        _ = runtime.loadFramework(path: Self.springBoardUIServicesPath)
    }

    /// Checks whether the real Apple Poster Gallery modal UI is supported on this system.
    public func isGallerySupported() -> Bool {
        ensureFrameworksLoaded()
        let hasEntryPoint = NSClassFromString("PRUISModalEntryPointGallery") != nil
        let hasController = NSClassFromString("PRUISModalController") != nil
        return hasEntryPoint && hasController
    }

    /// Checks whether Apple's Wallpaper Preview view controller is available on this system.
    public func isPreviewSupported() -> Bool {
        ensureFrameworksLoaded()
        return NSClassFromString("SBSUIWallpaperPreviewViewController") != nil
    }

    // MARK: - Phase 2A: Open Real Apple Wallpaper Gallery

    /// Presents Apple's genuine Wallpaper Gallery out-of-process via PosterBoardUIServices.
    #if canImport(UIKit)
    @MainActor
    public func openAppleGallery() async throws {
        SettingsLogger.info("Attempting to open Apple Wallpaper Gallery via PosterBoardUIServices...")

        ensureFrameworksLoaded()

        // 1. Resolve PRUISModalEntryPointGallery
        guard let entryPointCls = NSClassFromString("PRUISModalEntryPointGallery") as? NSObject.Type else {
            SettingsLogger.error("PRUISModalEntryPointGallery class not found in PosterBoardUIServices")
            throw WallpaperInstallError.classUnavailable(className: "PRUISModalEntryPointGallery")
        }

        // 2. Resolve PRUISModalController
        guard let modalCtrlCls = NSClassFromString("PRUISModalController") as? NSObject.Type else {
            SettingsLogger.error("PRUISModalController class not found in PosterBoardUIServices")
            throw WallpaperInstallError.classUnavailable(className: "PRUISModalController")
        }

        // 3. Locate active foreground UIWindowScene
        guard let windowScene = findActiveWindowScene() else {
            SettingsLogger.error("No active UIWindowScene found for presenting PRUISModalController")
            throw WallpaperInstallError.uiPresentationFailed(reason: "No active UIWindowScene found in foreground")
        }

        // 4. Instantiate entry point
        let entryPoint = entryPointCls.init()
        SettingsLogger.info("Instantiated PRUISModalEntryPointGallery: \(String(describing: entryPoint))")

        // 5. Instantiate PRUISModalController with entry point
        let initSel = NSSelectorFromString("initWithEntryPoint:")
        guard modalCtrlCls.instancesRespond(to: initSel),
              let initMethod = class_getInstanceMethod(modalCtrlCls, initSel) else {
            SettingsLogger.error("PRUISModalController does not respond to initWithEntryPoint:")
            throw WallpaperInstallError.selectorUnavailable(className: "PRUISModalController", selectorName: "initWithEntryPoint:")
        }

        typealias InitWithEntryPointFunc = @convention(c) (AnyObject, Selector, AnyObject) -> AnyObject?
        let initCallable = unsafeBitCast(method_getImplementation(initMethod), to: InitWithEntryPointFunc.self)

        guard let allocInstance = modalCtrlCls.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
              let controller = initCallable(allocInstance, initSel, entryPoint) else {
            SettingsLogger.error("Failed to initialize PRUISModalController with entry point")
            throw WallpaperInstallError.uiPresentationFailed(reason: "PRUISModalController initWithEntryPoint returned nil")
        }

        // 6. Strongly retain controller in memory so presentation persists
        self.activeModalController = controller

        // 7. Invoke presentFromWindowScene:
        let presentSel = NSSelectorFromString("presentFromWindowScene:")
        guard modalCtrlCls.instancesRespond(to: presentSel),
              let presentMethod = class_getInstanceMethod(modalCtrlCls, presentSel) else {
            SettingsLogger.error("PRUISModalController does not respond to presentFromWindowScene:")
            throw WallpaperInstallError.selectorUnavailable(className: "PRUISModalController", selectorName: "presentFromWindowScene:")
        }

        typealias PresentFunc = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        let presentCallable = unsafeBitCast(method_getImplementation(presentMethod), to: PresentFunc.self)

        presentCallable(controller, presentSel, windowScene)
        SettingsLogger.info("Invoked -[PRUISModalController presentFromWindowScene:] successfully")
    }
    #endif

    // MARK: - Phase 4: Preview Test Image in Apple UI

    /// Presents a wallpaper image inside Apple's genuine wallpaper preview view controller.
    #if canImport(UIKit)
    @MainActor
    public func presentWallpaperPreview(
        image: UIImage,
        from presentingViewController: UIViewController? = nil
    ) async throws {
        SettingsLogger.info("Attempting to present wallpaper preview via SpringBoardUIServices...")

        ensureFrameworksLoaded()

        guard let previewCls = NSClassFromString("SBSUIWallpaperPreviewViewController") as? UIViewController.Type else {
            SettingsLogger.error("SBSUIWallpaperPreviewViewController class not found")
            throw WallpaperInstallError.classUnavailable(className: "SBSUIWallpaperPreviewViewController")
        }

        guard let targetVC = presentingViewController ?? findTopViewController() else {
            SettingsLogger.error("No presenting UIViewController found")
            throw WallpaperInstallError.uiPresentationFailed(reason: "No valid presenting UIViewController found")
        }

        var previewVC: UIViewController?

        // Attempt 1: initWithImage:
        let initImageSel = NSSelectorFromString("initWithImage:")
        if previewCls.instancesRespond(to: initImageSel),
           let method = class_getInstanceMethod(previewCls, initImageSel) {
            typealias InitFunc = @convention(c) (AnyObject, Selector, UIImage) -> UIViewController?
            let callable = unsafeBitCast(method_getImplementation(method), to: InitFunc.self)
            if let allocInstance = previewCls.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() {
                previewVC = callable(allocInstance, initImageSel, image)
            }
        }

        // Attempt 2: initWithImage:name:
        if previewVC == nil {
            let initNameSel = NSSelectorFromString("initWithImage:name:")
            if previewCls.instancesRespond(to: initNameSel),
               let method = class_getInstanceMethod(previewCls, initNameSel) {
                typealias InitNameFunc = @convention(c) (AnyObject, Selector, UIImage, NSString) -> UIViewController?
                let callable = unsafeBitCast(method_getImplementation(method), to: InitNameFunc.self)
                if let allocInstance = previewCls.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() {
                    previewVC = callable(allocInstance, initNameSel, image, "Wallpaper" as NSString)
                }
            }
        }

        // Attempt 3: Standard alloc-init + setImage:
        if previewVC == nil {
            let instance = previewCls.init()
            let setImageSel = NSSelectorFromString("setImage:")
            if instance.responds(to: setImageSel) {
                _ = instance.perform(setImageSel, with: image)
            }
            previewVC = instance
        }

        guard let viewControllerToPresent = previewVC else {
            throw WallpaperInstallError.uiPresentationFailed(reason: "Could not instantiate SBSUIWallpaperPreviewViewController")
        }

        viewControllerToPresent.modalPresentationStyle = .fullScreen
        targetVC.present(viewControllerToPresent, animated: true)
        SettingsLogger.info("Presented SBSUIWallpaperPreviewViewController successfully")
    }
    #endif

    // MARK: - Dismissal / Cleanup

    /// Clears any active modal controller reference.
    public func dismissActiveModalController() {
        self.activeModalController = nil
    }

    // MARK: - Scene and View Controller Helpers

    #if canImport(UIKit)
    @MainActor
    private func findActiveWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first(where: { $0.activationState == .foregroundInactive })
            ?? scenes.first
    }

    @MainActor
    private func findTopViewController() -> UIViewController? {
        guard let windowScene = findActiveWindowScene(),
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
              var topVC = keyWindow.rootViewController else {
            return nil
        }

        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
    #endif
}
