import Foundation
import MachO
import UIKit

/// Detects whether the iOS device is jailbroken.
///
/// Checks: known jailbreak files, suspicious dylibs, Cydia URL scheme,
/// writable system paths.
class JailbreakDetectionHandler {

    func isDeviceJailbroken() -> Bool {
        return checkJailbreakFiles()
            || checkDylibs()
            || checkCydiaInstalled()
            || checkWritablePaths()
    }

    private func checkJailbreakFiles() -> Bool {
        let paths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/usr/bin/ssh",
            "/private/var/lib/cydia",
            "/private/var/stash",
            "/usr/libexec/sftp-server",
            "/var/cache/apt",
            "/var/lib/apt",
            "/usr/sbin/frida-server",
            "/usr/bin/cycript",
            "/usr/local/bin/cycript",
            "/usr/lib/libcycript.dylib"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private func checkDylibs() -> Bool {
        let suspiciousDylibs = [
            "SubstrateLoader.dylib",
            "SSLKillSwitch2.dylib",
            "SSLKillSwitch.dylib",
            "MobileSubstrate.dylib",
            "TweakInject.dylib",
            "CydiaSubstrate",
            "cynject",
            "CustomWidgetIcons",
            "FridaGadget",
            "frida-agent",
            "libcycript"
        ]
        let count = _dyld_image_count()
        for i in 0..<count {
            guard let name = _dyld_get_image_name(i) else { continue }
            let imageName = String(cString: name)
            for dylib in suspiciousDylibs {
                if imageName.lowercased().contains(dylib.lowercased()) {
                    return true
                }
            }
        }
        return false
    }

    /// Checks whether the Cydia URL scheme is registered, which indicates a
    /// jailbroken device.
    ///
    /// **Important:** For this check to return `true` on a jailbroken device,
    /// the host app's `Info.plist` must declare `cydia` under
    /// `LSApplicationQueriesSchemes`. Without that declaration iOS 9+ will
    /// always return `false` from `canOpenURL`, making the check a no-op.
    /// The remaining checks (`checkJailbreakFiles`, `checkDylibs`,
    /// `checkWritablePaths`) are reliable without any plist changes.
    private func checkCydiaInstalled() -> Bool {
        guard let url = URL(string: "cydia://package/com.example.package") else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }

    private func checkWritablePaths() -> Bool {
        let path = "/private/jailbreak_test_\(UUID().uuidString)"
        do {
            try "test".write(toFile: path, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            return false
        }
    }
}
