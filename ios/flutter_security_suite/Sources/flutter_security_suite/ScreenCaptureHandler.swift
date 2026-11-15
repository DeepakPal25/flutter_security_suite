import Flutter
import UIKit

/// Streams screen-capture events to Dart.
///
/// Events:
/// - `["type": "captureChanged", "isCaptured": Bool]` when recording,
///   AirPlay or mirroring starts / stops.
/// - `["type": "screenshot"]` after the user takes a screenshot (iOS reports
///   this after the fact; it cannot be prevented).
class ScreenCaptureHandler: NSObject, FlutterStreamHandler {

    private var sink: FlutterEventSink?
    private var lastCaptured: Bool?

    /// Returns `true` while the screen is being recorded or mirrored.
    func isCaptured() -> Bool {
        return UIScreen.main.isCaptured
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        removeObservers()
        sink = events
        lastCaptured = nil

        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(captureDidChange),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(screenshotTaken),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )

        // Emit the current state so late subscribers do not miss a recording
        // that is already running.
        emitCaptureState(force: true)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        removeObservers()
        sink = nil
        lastCaptured = nil
        return nil
    }

    deinit {
        removeObservers()
    }

    @objc private func captureDidChange() {
        onMain { self.emitCaptureState(force: false) }
    }

    @objc private func screenshotTaken() {
        onMain { self.sink?(["type": "screenshot"]) }
    }

    private func emitCaptureState(force: Bool) {
        let captured = isCaptured()
        if !force && captured == lastCaptured { return }
        lastCaptured = captured
        sink?(["type": "captureChanged", "isCaptured": captured])
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        center.removeObserver(self, name: UIScreen.capturedDidChangeNotification, object: nil)
        center.removeObserver(
            self,
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}
