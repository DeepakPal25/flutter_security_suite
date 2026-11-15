import Foundation
import MachO

/// Anti-tamper checks: debugger attachment and injected dynamic libraries.
class AntiTamperHandler {

    private static let suspiciousLibraries = [
        "fridagadget",
        "frida",
        "cynject",
        "libcycript",
        "substrateloader",
        "substrateinserter",
        "mobilesubstrate",
        "sslkillswitch",
        "libhooker",
        "substitute",
        "tweakinject",
        "ellekit",
    ]

    /// Returns `true` when the process is being traced (lldb, debugserver…).
    func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let status = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        // If the kernel refuses to answer we cannot prove a debugger is there.
        guard status == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    /// Returns `true` when `DYLD_INSERT_LIBRARIES` is set or a known
    /// instrumentation library is loaded into the process.
    func hasInjectedLibraries() -> Bool {
        #if targetEnvironment(simulator)
        // The simulator runtime itself is injected through
        // DYLD_INSERT_LIBRARIES, so the check is meaningless there.
        return false
        #else
        if let inserted = getenv("DYLD_INSERT_LIBRARIES"), strlen(inserted) > 0 {
            return true
        }
        for index in 0..<_dyld_image_count() {
            guard let rawName = _dyld_get_image_name(index) else { continue }
            let name = String(cString: rawName).lowercased()
            if AntiTamperHandler.suspiciousLibraries.contains(where: { name.contains($0) }) {
                return true
            }
        }
        return false
        #endif
    }

    /// Asks the kernel to refuse future debugger attachment
    /// (`ptrace(PT_DENY_ATTACH)`).
    ///
    /// Returns `false` without calling ptrace when a debugger is already
    /// attached (the call would kill the process) and on the simulator.
    func denyDebugger() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        if isDebuggerAttached() { return false }

        typealias PtraceFunction = @convention(c) (CInt, pid_t, CInt, CInt) -> CInt
        guard let handle = dlopen(nil, RTLD_NOW) else { return false }
        defer { dlclose(handle) }
        guard let symbol = dlsym(handle, "ptrace") else { return false }

        let ptrace = unsafeBitCast(symbol, to: PtraceFunction.self)
        let ptDenyAttach: CInt = 31
        return ptrace(ptDenyAttach, 0, 0, 0) == 0
        #endif
    }
}
