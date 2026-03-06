import UIKit

/// Detects whether the iOS screen is currently being captured (recorded
/// or mirrored to an external display).
///
/// Uses `UIScreen.isCaptured` which returns `true` whenever the screen
/// is being mirrored, AirPlayed, or recorded by ReplayKit / screen-record.
/// Requires iOS 11+.
class ScreenRecordingDetectionHandler {

    /// Returns `true` when the screen is actively being captured.
    func isScreenBeingRecorded() -> Bool {
        if #available(iOS 11.0, *) {
            return UIScreen.main.isCaptured
        }
        return false
    }
}
