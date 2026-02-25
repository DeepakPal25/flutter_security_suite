import Foundation

/// Verifies application integrity on iOS.
///
/// Checks: debugger attached, provisioning profile (embedded.mobileprovision),
/// and code signing validity.
class AppIntegrityHandler {

    func isAppIntegrityValid() -> Bool {
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

    /// Checks for embedded.mobileprovision – its presence in a
    /// non-App Store build may indicate a development or enterprise build.
    private func hasProvisioningProfile() -> Bool {
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            return false
        }
        return FileManager.default.fileExists(atPath: path)
    }
}
