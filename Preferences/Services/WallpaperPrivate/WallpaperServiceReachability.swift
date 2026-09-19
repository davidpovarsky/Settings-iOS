//
//  WallpaperServiceReachability.swift
//  Preferences
//
//  Audits process entitlements and dynamically probes PosterBoard XPC reachability
//  to detect sandbox/Mach lookup restrictions before making poster service calls.
//

import Foundation
import ObjectiveC.runtime
#if canImport(Darwin)
import Darwin
#endif

/// Audits process entitlements and probes PosterBoard XPC service connectivity.
public final class WallpaperServiceReachability: @unchecked Sendable {
    public static let shared = WallpaperServiceReachability()

    private init() {}

    // MARK: - Entitlement Keys

    public static let machLookupExceptionKey = "com.apple.security.exception.mach-lookup.global-name"
    public static let posterBoardServiceMachName = "com.apple.posterboardservices.services"
    public static let posterBoardClientEntitlement = "com.apple.posterboard.client"
    public static let posterBoardServicesEntitlement = "com.apple.posterboardservices"

    // MARK: - Public Audit API

    /// Performs a full reachability audit combining entitlement inspection and XPC probing.
    public func audit() -> ServiceReachabilityAudit {
        SettingsLogger.info("Auditing PosterBoard service reachability & entitlements...")

        let entitlementResult = auditEntitlements()
        let xpcResult = probePRSServiceXPC()

        let audit = ServiceReachabilityAudit(
            xpcStatus: xpcResult.status,
            prsServiceProbed: xpcResult.probed,
            prsServiceError: xpcResult.errorDescription,
            entitlementAudit: entitlementResult,
            auditedAt: Date()
        )

        SettingsLogger.info("Reachability audit complete: status=\(audit.xpcStatus.displayText), hasMachException=\(entitlementResult.hasPosterBoardLookupException)")
        return audit
    }

    /// Classifies an error to determine whether it is a sandbox / Mach lookup rejection.
    public func classifyError(_ error: Error) -> XPCReachabilityStatus {
        let nsError = error as NSError
        if nsError.domain == "PRSService" && nsError.code == 1 {
            return .blockedBySandbox(reason: "PRSService:1 - com.apple.posterboardservices.services blocked by Mach lookup sandbox")
        }

        if let installError = error as? WallpaperInstallError,
           let details = installError.failureDetails,
           details.domain == "PRSService" && details.code == 1 {
            return .blockedBySandbox(reason: "PRSService:1 - com.apple.posterboardservices.services blocked by Mach lookup sandbox")
        }

        return .unreachable(reason: error.localizedDescription)
    }

    // MARK: - Entitlement Inspection (via Dynamic SecTask)

    /// Dynamically inspects process entitlements using SecTask without linking private headers.
    public func auditEntitlements() -> EntitlementAuditResult {
        #if canImport(Darwin)
        guard let defaultHandle = dlopen(nil, RTLD_NOW) else {
            return EntitlementAuditResult(
                machLookupExceptions: [],
                hasPosterBoardLookupException: false,
                rawEntitlements: [:],
                auditError: "dlopen(nil) failed to open process image"
            )
        }

        guard let secTaskCreatePtr = dlsym(defaultHandle, "SecTaskCreateFromSelf"),
              let secTaskCopyValuePtr = dlsym(defaultHandle, "SecTaskCopyValueForEntitlement") else {
            return EntitlementAuditResult(
                machLookupExceptions: [],
                hasPosterBoardLookupException: false,
                rawEntitlements: [:],
                auditError: "SecTask symbols not exported in this process"
            )
        }

        typealias SecTaskCreateFromSelfFunc = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
        typealias SecTaskCopyValueFunc = @convention(c) (
            AnyObject,
            CFString,
            UnsafeMutablePointer<Unmanaged<CFError>?>?
        ) -> Unmanaged<AnyObject>?

        let createFn = unsafeBitCast(secTaskCreatePtr, to: SecTaskCreateFromSelfFunc.self)
        let copyFn = unsafeBitCast(secTaskCopyValuePtr, to: SecTaskCopyValueFunc.self)

        guard let secTask = createFn(nil)?.takeRetainedValue() else {
            return EntitlementAuditResult(
                machLookupExceptions: [],
                hasPosterBoardLookupException: false,
                rawEntitlements: [:],
                auditError: "SecTaskCreateFromSelf returned nil"
            )
        }

        var machExceptions: [String] = []
        var rawDict: [String: String] = [:]

        // 1. Audit mach-lookup global-name exceptions
        var errorRef: Unmanaged<CFError>?
        let machLookupKey = Self.machLookupExceptionKey as CFString
        if let rawVal = copyFn(secTask, machLookupKey, &errorRef)?.takeRetainedValue() {
            if let arr = rawVal as? [String] {
                machExceptions = arr
                rawDict[Self.machLookupExceptionKey] = arr.joined(separator: ", ")
            } else if let single = rawVal as? String {
                machExceptions = [single]
                rawDict[Self.machLookupExceptionKey] = single
            }
        }

        // 2. Audit other PosterBoard client keys
        let probeKeys = [
            Self.posterBoardClientEntitlement,
            Self.posterBoardServicesEntitlement,
            Self.posterBoardServiceMachName
        ]

        for key in probeKeys {
            var err: Unmanaged<CFError>?
            if let val = copyFn(secTask, key as CFString, &err)?.takeRetainedValue() {
                rawDict[key] = String(describing: val)
            }
        }

        let hasPosterBoardException = machExceptions.contains {
            $0 == Self.posterBoardServiceMachName || $0.contains("posterboard")
        }

        return EntitlementAuditResult(
            machLookupExceptions: machExceptions,
            hasPosterBoardLookupException: hasPosterBoardException,
            rawEntitlements: rawDict,
            auditError: nil
        )
        #else
        return EntitlementAuditResult(
            machLookupExceptions: [],
            hasPosterBoardLookupException: false,
            rawEntitlements: [:],
            auditError: "Entitlement inspection only supported on Darwin"
        )
        #endif
    }

    // MARK: - PRSService XPC Reachability Probing

    /// Probes PRSService interface dynamically to check if the remote Mach target can be acquired.
    public func probePRSServiceXPC() -> (status: XPCReachabilityStatus, probed: Bool, errorDescription: String?) {
        let runtime = WallpaperPrivateRuntime.shared
        _ = runtime.loadAllTargetFrameworks()

        guard let prsCls = runtime.resolveClass("PRSService") as? NSObject.Type else {
            return (.unreachable(reason: "PRSService class not found"), false, nil)
        }

        // Resolve service instance
        let serviceSel = NSSelectorFromString("service")
        let sharedSel = NSSelectorFromString("sharedInstance")
        let serviceInstance: AnyObject

        if prsCls.responds(to: serviceSel),
           let method = class_getClassMethod(prsCls, serviceSel) {
            typealias Getter = @convention(c) (AnyClass, Selector) -> AnyObject?
            let getter = unsafeBitCast(method_getImplementation(method), to: Getter.self)
            guard let inst = getter(prsCls, serviceSel) else {
                return (.unreachable(reason: "PRSService.service returned nil"), true, nil)
            }
            serviceInstance = inst
        } else if prsCls.responds(to: sharedSel),
                  let method = class_getClassMethod(prsCls, sharedSel) {
            typealias Getter = @convention(c) (AnyClass, Selector) -> AnyObject?
            let getter = unsafeBitCast(method_getImplementation(method), to: Getter.self)
            guard let inst = getter(prsCls, sharedSel) else {
                return (.unreachable(reason: "PRSService.sharedInstance returned nil"), true, nil)
            }
            serviceInstance = inst
        } else {
            serviceInstance = prsCls.init()
        }

        // Probe _serviceInterfaceWithError:
        let ifaceSel = NSSelectorFromString("_serviceInterfaceWithError:")
        if serviceInstance.responds(to: ifaceSel),
           let method = class_getInstanceMethod(object_getClass(serviceInstance), ifaceSel) {
            typealias InterfaceGetter = @convention(c) (
                AnyObject,
                Selector,
                AutoreleasingUnsafeMutablePointer<NSError?>?
            ) -> AnyObject?

            let getter = unsafeBitCast(method_getImplementation(method), to: InterfaceGetter.self)
            var error: NSError?
            let iface = getter(serviceInstance, ifaceSel, &error)

            if let err = error {
                let errDesc = "\(err.domain):\(err.code) (\(err.localizedDescription))"
                if err.domain == "PRSService" && err.code == 1 {
                    return (.blockedBySandbox(reason: "PRSService:1 (Mach lookup target blocked)"), true, errDesc)
                } else {
                    return (.unreachable(reason: "\(err.domain):\(err.code)"), true, errDesc)
                }
            } else if iface != nil {
                return (.available, true, nil)
            } else {
                return (.unreachable(reason: "_serviceInterface returned nil without error"), true, nil)
            }
        }

        // If _serviceInterfaceWithError: is not directly accessible, return unknown but note PRSService exists
        return (.unknown, true, nil)
    }
}
