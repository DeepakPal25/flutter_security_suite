import Foundation
import LocalAuthentication

/// Outcome of a biometric prompt.
enum BiometricOutcome {
    /// `true` when authenticated, `false` when the user or system cancelled.
    case finished(Bool)
    /// A failure with one of the `BIOMETRIC_*` codes.
    case failed(code: String, message: String)
}

/// Biometric authentication through `LAContext`.
///
/// Face ID requires `NSFaceIDUsageDescription` in the host app's Info.plist;
/// iOS terminates apps that evaluate Face ID without it, so that case is
/// reported as `BIOMETRIC_NOT_AVAILABLE` instead.
class BiometricHandler {

    private static let notAvailable   = "BIOMETRIC_NOT_AVAILABLE"
    private static let notEnrolled    = "BIOMETRIC_NOT_ENROLLED"
    private static let lockedOut      = "BIOMETRIC_LOCKED_OUT"
    private static let passcodeNotSet = "BIOMETRIC_PASSCODE_NOT_SET"
    private static let inProgress     = "BIOMETRIC_IN_PROGRESS"
    private static let generic        = "BIOMETRIC_ERROR"

    private var isAuthenticating = false

    func availability() -> [String: Any?] {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        let type = typeName(context.biometryType)

        if canEvaluate {
            if context.biometryType == .faceID && !hasFaceIDUsageDescription() {
                return [
                    "available": false,
                    "type": "none",
                    "reason": BiometricHandler.notAvailable,
                ]
            }
            return ["available": true, "type": type, "reason": nil]
        }
        return [
            "available": false,
            "type": "none",
            "reason": code(for: error),
        ]
    }

    /// Must be called on the main thread. `completion` is always invoked
    /// exactly once, on the main queue.
    func authenticate(
        reason: String,
        allowDeviceCredential: Bool,
        cancelLabel: String?,
        completion: @escaping (BiometricOutcome) -> Void
    ) {
        if isAuthenticating {
            completion(.failed(
                code: BiometricHandler.inProgress,
                message: "Another authentication is already in progress"
            ))
            return
        }

        let context = LAContext()
        if let cancelLabel = cancelLabel, !cancelLabel.isEmpty {
            context.localizedCancelTitle = cancelLabel
        }
        let policy: LAPolicy
        if allowDeviceCredential {
            policy = .deviceOwnerAuthentication
        } else {
            policy = .deviceOwnerAuthenticationWithBiometrics
            // An empty title hides the "Enter Password" fallback button.
            context.localizedFallbackTitle = ""
        }

        var error: NSError?
        guard context.canEvaluatePolicy(policy, error: &error) else {
            completion(.failed(
                code: code(for: error),
                message: error?.localizedDescription ?? "Authentication is not available"
            ))
            return
        }
        if context.biometryType == .faceID && !hasFaceIDUsageDescription() {
            completion(.failed(
                code: BiometricHandler.notAvailable,
                message: "NSFaceIDUsageDescription is missing from Info.plist"
            ))
            return
        }

        isAuthenticating = true
        context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, evalError in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAuthenticating = false
                if success {
                    completion(.finished(true))
                    return
                }
                let nsError = evalError as NSError?
                if self.isCancellation(nsError) {
                    completion(.finished(false))
                } else {
                    completion(.failed(
                        code: self.code(for: nsError),
                        message: nsError?.localizedDescription ?? "Authentication failed"
                    ))
                }
            }
        }
    }

    private func isCancellation(_ error: NSError?) -> Bool {
        guard let error = error, error.domain == LAError.errorDomain,
              let code = LAError.Code(rawValue: error.code) else { return false }
        switch code {
        case .userCancel, .appCancel, .systemCancel, .userFallback:
            return true
        default:
            return false
        }
    }

    private func code(for error: NSError?) -> String {
        guard let error = error, error.domain == LAError.errorDomain,
              let code = LAError.Code(rawValue: error.code) else {
            return BiometricHandler.generic
        }
        switch code {
        case .biometryLockout:
            return BiometricHandler.lockedOut
        case .biometryNotEnrolled:
            return BiometricHandler.notEnrolled
        case .biometryNotAvailable:
            return BiometricHandler.notAvailable
        case .passcodeNotSet:
            return BiometricHandler.passcodeNotSet
        default:
            return BiometricHandler.generic
        }
    }

    private func typeName(_ type: LABiometryType) -> String {
        if #available(iOS 17.0, *), type == .opticID { return "iris" }
        switch type {
        case .faceID:
            return "face"
        case .touchID:
            return "fingerprint"
        default:
            return "none"
        }
    }

    private func hasFaceIDUsageDescription() -> Bool {
        let value = Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") as? String
        return !(value ?? "").isEmpty
    }
}
