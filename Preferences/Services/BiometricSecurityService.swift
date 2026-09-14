import Foundation
import LocalAuthentication

/// Service providing native biometric authentication (Face ID / Touch ID / Device Passcode)
/// to guard sensitive operations like revealing or editing secret API credentials.
@MainActor
public final class BiometricSecurityService: ObservableObject {
    public static let shared = BiometricSecurityService()

    @Published public var isBiometricsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBiometricsEnabled, forKey: "security.requireBiometrics")
        }
    }

    public init() {
        self.isBiometricsEnabled = UserDefaults.standard.bool(forKey: "security.requireBiometrics")
    }

    public enum BiometricType {
        case none
        case touchID
        case faceID
        case opticID

        public var displayName: String {
            switch self {
            case .none: return "Passcode"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            case .opticID: return "Optic ID"
            }
        }

        public var systemImage: String {
            switch self {
            case .none: return "lock.fill"
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            case .opticID: return "eye.fill"
            }
        }
    }

    public var availableBiometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:
            return .opticID
        default:
            return .none
        }
    }

    /// Authenticates the user using biometrics or passcode.
    ///
    /// - Parameter reason: User-visible explanation for the authentication prompt.
    /// - Returns: `true` if authentication succeeded or if security is not enforced; `false` on cancel/failure.
    public func authenticate(reason: String = "Unlock to view or modify sensitive credentials") async -> Bool {
        guard isBiometricsEnabled else {
            return true
        }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) { success, _ in
                Task { @MainActor in
                    continuation.resume(returning: success)
                }
            }
        }
    }
}
