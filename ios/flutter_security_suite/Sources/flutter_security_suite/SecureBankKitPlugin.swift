import Flutter
import UIKit

public class SecureBankKitPlugin: NSObject, FlutterPlugin {

    private let jailbreakHandler        = JailbreakDetectionHandler()
    private let screenshotHandler       = ScreenshotHandler()
    private let integrityHandler        = AppIntegrityHandler()
    private let storageHandler          = SecureStorageHandler()
    private let emulatorHandler         = EmulatorDetectionHandler()
    private let recordingHandler        = ScreenRecordingDetectionHandler()
    private let tamperHandler           = TamperDetectionHandler()
    private let runtimeHandler          = RuntimeProtectionHandler()
    private let antiTamperHandler       = AntiTamperHandler()
    private let screenCaptureHandler    = ScreenCaptureHandler()
    private let pasteboardHandler       = PasteboardHandler()
    private let biometricHandler        = BiometricHandler()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.securebankkit/security",
            binaryMessenger: registrar.messenger()
        )
        let instance = SecureBankKitPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let screenCaptureChannel = FlutterEventChannel(
            name: "com.securebankkit/screen_capture_events",
            binaryMessenger: registrar.messenger()
        )
        screenCaptureChannel.setStreamHandler(instance.screenCaptureHandler)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        // ── Root / Jailbreak Detection ──────────────
        case "root#isDeviceRooted":
            result(jailbreakHandler.isDeviceJailbroken())

        // ── Screenshot Protection ───────────────────
        // result(nil) is called inside the completion block so that success is
        // only reported after the protection is actually applied (the enable/
        // disable work is dispatched asynchronously to the main queue).
        case "screenshot#enable":
            screenshotHandler.enable { result(nil) }

        case "screenshot#disable":
            screenshotHandler.disable { result(nil) }

        // ── App Integrity ───────────────────────────
        case "integrity#isValid":
            result(integrityHandler.isAppIntegrityValid())

        // ── Secure Storage ──────────────────────────
        case "storage#write":
            guard let args = call.arguments as? [String: Any],
                  let key = args["key"] as? String,
                  let value = args["value"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "key and value are required",
                    details: nil
                ))
                return
            }
            let success = storageHandler.write(key: key, value: value)
            if success {
                result(nil)
            } else {
                result(FlutterError(
                    code: "STORAGE_ERROR",
                    message: "Failed to write to keychain",
                    details: nil
                ))
            }

        case "storage#read":
            guard let args = call.arguments as? [String: Any],
                  let key = args["key"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "key is required",
                    details: nil
                ))
                return
            }
            result(storageHandler.read(key: key))

        case "storage#delete":
            guard let args = call.arguments as? [String: Any],
                  let key = args["key"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "key is required",
                    details: nil
                ))
                return
            }
            let success = storageHandler.delete(key: key)
            if success {
                result(nil)
            } else {
                result(FlutterError(
                    code: "STORAGE_ERROR",
                    message: "Failed to delete from keychain",
                    details: nil
                ))
            }

        case "storage#deleteAll":
            let success = storageHandler.deleteAll()
            if success {
                result(nil)
            } else {
                result(FlutterError(
                    code: "STORAGE_ERROR",
                    message: "Failed to clear keychain",
                    details: nil
                ))
            }

        // ── Emulator Detection ──────────────────────────
        case "emulator#isEmulator":
            result(emulatorHandler.isEmulator())

        // ── Screen Recording Detection ───────────────────
        case "recording#isRecording":
            result(recordingHandler.isScreenBeingRecorded())

        // ── Tamper Detection ─────────────────────────────
        case "tamper#isTampered":
            result(tamperHandler.isTampered())

        // ── Runtime Protection ───────────────────────────
        case "runtime#isHooked":
            result(runtimeHandler.isRuntimeHooked())

        // ── Anti-Tamper ──────────────────────────────────
        case "antitamper#isDebuggerAttached":
            result(antiTamperHandler.isDebuggerAttached())

        case "antitamper#hasInjectedLibraries":
            result(antiTamperHandler.hasInjectedLibraries())

        case "antitamper#denyDebugger":
            result(antiTamperHandler.denyDebugger())

        // ── Screen Capture Monitoring ────────────────────
        case "screencapture#isCaptured":
            result(screenCaptureHandler.isCaptured())

        // ── Pasteboard Protection ────────────────────────
        case "pasteboard#copy":
            guard let args = call.arguments as? [String: Any],
                  let value = args["value"] as? String,
                  let expiresAfterMs = (args["expiresAfterMs"] as? NSNumber)?.doubleValue,
                  expiresAfterMs > 0 else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "value and a positive expiresAfterMs are required",
                    details: nil
                ))
                return
            }
            pasteboardHandler.copy(value: value, expiresAfterMs: expiresAfterMs)
            result(nil)

        case "pasteboard#clear":
            let args = call.arguments as? [String: Any]
            let onlyIfOwned = args?["onlyIfOwned"] as? Bool ?? true
            result(pasteboardHandler.clear(onlyIfOwned: onlyIfOwned))

        // ── Biometric Authentication ─────────────────────
        case "biometric#availability":
            result(biometricHandler.availability())

        case "biometric#authenticate":
            guard let args = call.arguments as? [String: Any],
                  let reason = args["reason"] as? String,
                  !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "reason is required",
                    details: nil
                ))
                return
            }
            biometricHandler.authenticate(
                reason: reason,
                allowDeviceCredential: args["allowDeviceCredential"] as? Bool ?? true,
                cancelLabel: args["cancelLabel"] as? String
            ) { outcome in
                switch outcome {
                case .finished(let authenticated):
                    result(authenticated)
                case .failed(let code, let message):
                    result(FlutterError(code: code, message: message, details: nil))
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
