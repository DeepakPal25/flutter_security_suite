import Foundation

/// Verifies application integrity on iOS.
///
/// `isAppIntegrityValid()` returns `false` when a debugger is attached,
/// covering both development and runtime attach scenarios.
///
/// To distinguish **App Store** builds from **TestFlight** builds, use
/// `isAppStoreBuild()`. TestFlight builds contain an embedded provisioning
/// profile whereas App Store builds do not — both are valid distribution
/// channels and will pass `isAppIntegrityValid()`.
class AppIntegrityHandler {

    /// Returns `true` when the app is running without a debugger attached.
    /// Both App Store and TestFlight distribution builds are considered valid.
    func isAppIntegrityValid() -> Bool {
        return !isDebuggerAttached()
    }

    /// Returns `true` only for App Store release builds (no provisioning
    /// profile, no debugger). TestFlight builds will return `false` here
    /// because TestFlight embeds a provisioning profile.
    func isAppStoreBuild() -> Bool {
        return !isDebuggerAttached() && !hasProvisioningProfile()
    }

    private func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    /// Returns `true` when an embedded provisioning profile is present.
    /// This is `true` for development and TestFlight builds, and `false`
    /// for App Store release builds.
    private func hasProvisioningProfile() -> Bool {
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            return false
        }
        return FileManager.default.fileExists(atPath: path)
    }
}
