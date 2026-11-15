package com.securebankkit.flutter_security_suite

import android.app.Activity
import android.content.Context
import androidx.annotation.NonNull
import com.securebankkit.flutter_security_suite.handlers.AntiTamperHandler
import com.securebankkit.flutter_security_suite.handlers.AppIntegrityHandler
import com.securebankkit.flutter_security_suite.handlers.BiometricHandler
import com.securebankkit.flutter_security_suite.handlers.EmulatorDetectionHandler
import com.securebankkit.flutter_security_suite.handlers.PasteboardHandler
import com.securebankkit.flutter_security_suite.handlers.RootDetectionHandler
import com.securebankkit.flutter_security_suite.handlers.RuntimeProtectionHandler
import com.securebankkit.flutter_security_suite.handlers.ScreenCaptureHandler
import com.securebankkit.flutter_security_suite.handlers.ScreenRecordingDetectionHandler
import com.securebankkit.flutter_security_suite.handlers.ScreenshotHandler
import com.securebankkit.flutter_security_suite.handlers.SecureStorageHandler
import com.securebankkit.flutter_security_suite.handlers.TamperDetectionHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class SecureBankKitPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var screenCaptureEventChannel: EventChannel
    private lateinit var context: Context
    private var activity: Activity? = null

    // Handlers that require Context are initialised in onAttachedToEngine.
    private lateinit var rootHandler: RootDetectionHandler
    private lateinit var screenCaptureHandler: ScreenCaptureHandler
    private lateinit var pasteboardHandler: PasteboardHandler
    private val screenshotHandler         = ScreenshotHandler()
    private val integrityHandler          = AppIntegrityHandler()
    private val storageHandler            = SecureStorageHandler()
    private val emulatorHandler           = EmulatorDetectionHandler()
    private val screenRecordingHandler    = ScreenRecordingDetectionHandler()
    private val tamperHandler             = TamperDetectionHandler()
    private val runtimeHandler            = RuntimeProtectionHandler()
    private val antiTamperHandler         = AntiTamperHandler()
    private val biometricHandler          = BiometricHandler()

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        rootHandler = RootDetectionHandler(context)
        channel = MethodChannel(binding.binaryMessenger, "com.securebankkit/security")
        channel.setMethodCallHandler(this)

        screenCaptureHandler = ScreenCaptureHandler(context)
        pasteboardHandler = PasteboardHandler(context)
        screenCaptureEventChannel =
            EventChannel(binding.binaryMessenger, "com.securebankkit/screen_capture_events")
        screenCaptureEventChannel.setStreamHandler(screenCaptureHandler)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        screenCaptureEventChannel.setStreamHandler(null)
        screenCaptureHandler.dispose()
        pasteboardHandler.dispose()
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            // ── Root Detection ──────────────────────────
            "root#isDeviceRooted" -> {
                result.success(rootHandler.isDeviceRooted())
            }

            // ── Screenshot Protection ───────────────────
            "screenshot#enable" -> {
                // Capture the activity reference before the lambda to avoid a
                // TOCTOU race where activity detaches between the null-check
                // and the lambda execution.
                val currentActivity = activity
                if (currentActivity != null) {
                    currentActivity.runOnUiThread {
                        screenshotHandler.enable(currentActivity)
                        result.success(null)
                    }
                } else {
                    result.error("NO_ACTIVITY", "No activity attached", null)
                }
            }
            "screenshot#disable" -> {
                val currentActivity = activity
                if (currentActivity != null) {
                    currentActivity.runOnUiThread {
                        screenshotHandler.disable(currentActivity)
                        result.success(null)
                    }
                } else {
                    result.error("NO_ACTIVITY", "No activity attached", null)
                }
            }

            // ── App Integrity ───────────────────────────
            "integrity#isValid" -> {
                result.success(integrityHandler.isAppIntegrityValid(context))
            }

            // ── Secure Storage ──────────────────────────
            "storage#write" -> {
                val key = call.argument<String>("key")
                val value = call.argument<String>("value")
                if (key != null && value != null) {
                    storageHandler.write(context, key, value)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "key and value are required", null)
                }
            }
            "storage#read" -> {
                val key = call.argument<String>("key")
                if (key != null) {
                    result.success(storageHandler.read(context, key))
                } else {
                    result.error("INVALID_ARGS", "key is required", null)
                }
            }
            "storage#delete" -> {
                val key = call.argument<String>("key")
                if (key != null) {
                    storageHandler.delete(context, key)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "key is required", null)
                }
            }
            "storage#deleteAll" -> {
                storageHandler.deleteAll(context)
                result.success(null)
            }

            // ── Emulator Detection ───────────────────────
            "emulator#isEmulator" -> {
                result.success(emulatorHandler.isEmulator())
            }

            // ── Screen Recording Detection ────────────────
            "recording#isRecording" -> {
                result.success(screenRecordingHandler.isScreenBeingRecorded(context))
            }

            // ── Tamper Detection ──────────────────────────
            "tamper#isTampered" -> {
                result.success(tamperHandler.isTampered(context))
            }
            "tamper#getSignatureHash" -> {
                result.success(tamperHandler.getSigningCertificateHash(context))
            }

            // ── Runtime Protection ────────────────────────
            "runtime#isHooked" -> {
                result.success(runtimeHandler.isRuntimeHooked())
            }

            // ── Anti-Tamper ───────────────────────────────
            "antitamper#isDebuggerAttached" -> {
                result.success(antiTamperHandler.isDebuggerAttached())
            }
            "antitamper#hasInjectedLibraries" -> {
                result.success(antiTamperHandler.hasInjectedLibraries())
            }
            "antitamper#denyDebugger" -> {
                result.success(antiTamperHandler.denyDebugger(context))
            }

            // ── Screen Capture Monitoring ─────────────────
            "screencapture#isCaptured" -> {
                result.success(screenCaptureHandler.isCaptured())
            }

            // ── Pasteboard Protection ─────────────────────
            "pasteboard#copy" -> {
                val value = call.argument<String>("value")
                val expiresAfterMs = call.argument<Number>("expiresAfterMs")?.toLong()
                if (value == null || expiresAfterMs == null || expiresAfterMs <= 0) {
                    result.error(
                        "INVALID_ARGS",
                        "value and a positive expiresAfterMs are required",
                        null,
                    )
                } else {
                    try {
                        pasteboardHandler.copy(value, expiresAfterMs)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("PASTEBOARD_ERROR", e.message, null)
                    }
                }
            }
            "pasteboard#clear" -> {
                val onlyIfOwned = call.argument<Boolean>("onlyIfOwned") ?: true
                result.success(pasteboardHandler.clear(onlyIfOwned))
            }

            // ── Biometric Authentication ──────────────────
            "biometric#availability" -> {
                result.success(biometricHandler.availability(context))
            }
            "biometric#authenticate" -> {
                val reason = call.argument<String>("reason")
                if (reason.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "reason is required", null)
                } else {
                    biometricHandler.authenticate(
                        activity,
                        reason,
                        call.argument<Boolean>("allowDeviceCredential") ?: true,
                        call.argument<String>("cancelLabel"),
                        result,
                    )
                }
            }

            else -> result.notImplemented()
        }
    }

    // ── ActivityAware ───────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        screenCaptureHandler.setActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        screenCaptureHandler.setActivity(null)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        screenCaptureHandler.setActivity(binding.activity)
    }

    override fun onDetachedFromActivity() {
        activity = null
        screenCaptureHandler.setActivity(null)
    }
}
