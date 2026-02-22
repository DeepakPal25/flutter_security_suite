package com.securebankkit.flutter_security_suite

import android.app.Activity
import android.content.Context
import androidx.annotation.NonNull
import com.securebankkit.flutter_security_suite.handlers.AppIntegrityHandler
import com.securebankkit.flutter_security_suite.handlers.RootDetectionHandler
import com.securebankkit.flutter_security_suite.handlers.ScreenshotHandler
import com.securebankkit.flutter_security_suite.handlers.SecureStorageHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class SecureBankKitPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null

    private val rootHandler = RootDetectionHandler()
    private val screenshotHandler = ScreenshotHandler()
    private val integrityHandler = AppIntegrityHandler()
    private val storageHandler = SecureStorageHandler()

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.securebankkit/security")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            // ── Root Detection ──────────────────────────
            "root#isDeviceRooted" -> {
                result.success(rootHandler.isDeviceRooted())
            }

            // ── Screenshot Protection ───────────────────
            "screenshot#enable" -> {
                activity?.runOnUiThread {
                    screenshotHandler.enable(activity)
                    result.success(null)
                } ?: result.error("NO_ACTIVITY", "No activity attached", null)
            }
            "screenshot#disable" -> {
                activity?.runOnUiThread {
                    screenshotHandler.disable(activity)
                    result.success(null)
                } ?: result.error("NO_ACTIVITY", "No activity attached", null)
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

            else -> result.notImplemented()
        }
    }

    // ── ActivityAware ───────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
