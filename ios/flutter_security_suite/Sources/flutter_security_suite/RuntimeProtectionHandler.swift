import Foundation
import MachO

/// Detects active runtime instrumentation frameworks such as Frida.
///
/// Checks:
/// - Frida default server port (27042) – present when `frida-server` runs
/// - Frida-related dylibs loaded into the process
/// - Frida environment variables injected by the gadget loader
///
/// Note: Jailbreak detection (JailbreakDetectionHandler) overlaps with
/// some dylib checks; this handler focuses narrowly on instrumentation
/// tools that may run without a full jailbreak (e.g. Frida gadget injected
/// into a re-packaged IPA).
class RuntimeProtectionHandler {

    func isRuntimeHooked() -> Bool {
        return checkFridaPort()
            || checkFridaDylibs()
            || checkFridaEnvironment()
    }

    // MARK: - Private checks

    /// Attempts a TCP connection to the default Frida server port on localhost.
    /// Returns `true` if the port is open (i.e. frida-server is listening).
    private func checkFridaPort() -> Bool {
        let sock = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard sock != -1 else { return false }
        defer { Darwin.close(sock) }

        // Non-blocking connect attempt with a short timeout via SO_SNDTIMEO.
        var timeout = timeval(tv_sec: 0, tv_usec: 100_000) // 100 ms
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port   = UInt16(27042).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return connected == 0
    }

    /// Scans loaded dyld images for Frida gadget / agent libraries.
    private func checkFridaDylibs() -> Bool {
        let signatures = ["frida", "gadget", "agent"]
        let count = _dyld_image_count()
        for i in 0..<count {
            guard let namePtr = _dyld_get_image_name(i) else { continue }
            let name = String(cString: namePtr).lowercased()
            if signatures.contains(where: { name.contains($0) }) {
                return true
            }
        }
        return false
    }

    /// Checks for environment variables that Frida's gadget injects.
    private func checkFridaEnvironment() -> Bool {
        let env = ProcessInfo.processInfo.environment
        return env["FRIDA_PAYLOAD_PATH"] != nil
            || env["FRIDA_DYLIB_PATH"] != nil
    }
}
