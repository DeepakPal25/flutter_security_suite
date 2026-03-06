import Foundation

/// Detects whether the app is running inside the iOS Simulator.
///
/// Compile-time flag (`#if targetEnvironment(simulator)`) is the primary
/// check; a runtime environment-variable check provides defence-in-depth
/// against tooling that spoofs the compile-time constant.
class EmulatorDetectionHandler {

    func isEmulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return checkSimulatorEnvironment()
        #endif
    }

    /// Checks ProcessInfo environment variables set by Xcode when launching
    /// inside the Simulator. These are absent on real hardware.
    private func checkSimulatorEnvironment() -> Bool {
        let env = ProcessInfo.processInfo.environment
        return env["SIMULATOR_DEVICE_NAME"] != nil
            || env["SIMULATOR_RUNTIME_VERSION"] != nil
            || env["SIMULATOR_UDID"] != nil
    }
}
