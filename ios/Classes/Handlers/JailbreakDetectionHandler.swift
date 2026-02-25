import Foundation

/// Detects whether the iOS device is jailbroken.
///
/// Checks: known jailbreak files, dylibs, fork ability, writable system paths.
class JailbreakDetectionHandler {

    func isDeviceJailbroken() -> Bool {
        return checkJailbreakFiles()
            || checkDylibs()
            || checkFork()
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

    private func checkFork() -> Bool {
        let pid = fork()
        if pid >= 0 {
            // Fork succeeded → jailbroken (sandbox should prevent this)
            if pid > 0 {
                kill(pid, SIGTERM)
            }
            return true
        }
        return false
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
