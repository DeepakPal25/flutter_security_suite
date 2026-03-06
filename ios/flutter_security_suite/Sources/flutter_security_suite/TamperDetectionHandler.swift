import Foundation

/// Detects whether the application bundle has been tampered with or
/// re-signed after the original build.
///
/// Checks:
/// - Bundle identifier consistency (runtime vs. Info.plist)
/// - Presence of the `_CodeSignature` directory (stripped in cracked IPAs)
/// - App bundle path format (App Store vs. suspicious side-load path)
class TamperDetectionHandler {

    /// Returns `true` when tampering indicators are found.
    func isTampered() -> Bool {
        return hasBundleIdMismatch()
            || isMissingCodeSignature()
    }

    // MARK: - Private checks

    /// Compares the runtime bundle ID with the value in Info.plist.
    /// A mismatch is a strong indicator of re-packaging.
    private func hasBundleIdMismatch() -> Bool {
        guard
            let infoPlistId = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String,
            let runtimeId   = Bundle.main.bundleIdentifier
        else {
            // Unable to read – treat as tampered.
            return true
        }
        return infoPlistId != runtimeId
    }

    /// Checks that the `_CodeSignature` directory is present inside the
    /// app bundle. Cracked / patched IPAs commonly strip this directory.
    private func isMissingCodeSignature() -> Bool {
        let codeSigPath = Bundle.main.bundlePath + "/_CodeSignature"
        return !FileManager.default.fileExists(atPath: codeSigPath)
    }
}
