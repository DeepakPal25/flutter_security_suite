import Flutter
import UIKit

public class SecureBankKitPlugin: NSObject, FlutterPlugin {

    private let jailbreakHandler = JailbreakDetectionHandler()
    private let screenshotHandler = ScreenshotHandler()
    private let integrityHandler = AppIntegrityHandler()
    private let storageHandler = SecureStorageHandler()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.securebankkit/security",
            binaryMessenger: registrar.messenger()
        )
        let instance = SecureBankKitPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        // ── Root / Jailbreak Detection ──────────────
        case "root#isDeviceRooted":
            result(jailbreakHandler.isDeviceJailbroken())

        // ── Screenshot Protection ───────────────────
        case "screenshot#enable":
            screenshotHandler.enable()
            result(nil)

        case "screenshot#disable":
            screenshotHandler.disable()
            result(nil)

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
            let _ = storageHandler.delete(key: key)
            result(nil)

        case "storage#deleteAll":
            let _ = storageHandler.deleteAll()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
