package com.securebankkit.flutter_security_suite.handlers

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Biometric authentication through AndroidX [BiometricPrompt].
 *
 * The host activity must be a [FragmentActivity] (use
 * `FlutterFragmentActivity` in the app's MainActivity).
 *
 * Replies: `true` on success, `false` when the user or system cancelled, and
 * an error with one of the `BIOMETRIC_*` codes otherwise.
 *
 * All methods must be called on the main thread.
 */
class BiometricHandler {

    private var pendingResult: Result? = null

    fun availability(context: Context): Map<String, Any?> {
        val status = try {
            BiometricManager.from(context).canAuthenticate(Authenticators.BIOMETRIC_STRONG)
        } catch (_: Exception) {
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE
        }
        return when (status) {
            BiometricManager.BIOMETRIC_SUCCESS -> mapOf(
                "available" to true,
                "type" to biometricType(context),
                "reason" to null,
            )
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> mapOf(
                "available" to false,
                "type" to "none",
                "reason" to NOT_ENROLLED,
            )
            else -> mapOf(
                "available" to false,
                "type" to "none",
                "reason" to NOT_AVAILABLE,
            )
        }
    }

    fun authenticate(
        activity: Activity?,
        reason: String,
        allowDeviceCredential: Boolean,
        cancelLabel: String?,
        result: Result,
    ) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "No activity attached", null)
            return
        }
        if (activity !is FragmentActivity) {
            result.error(
                "NO_ACTIVITY",
                "Biometric prompts need a FragmentActivity. Make MainActivity " +
                    "extend FlutterFragmentActivity.",
                null,
            )
            return
        }
        if (pendingResult != null) {
            result.error(IN_PROGRESS, "Another authentication is already in progress", null)
            return
        }
        if (activity.isFinishing || activity.supportFragmentManager.isStateSaved) {
            // BiometricPrompt silently drops requests made after
            // onSaveInstanceState, which would leave the Dart future hanging.
            result.error(GENERIC, "The app is not in the foreground", null)
            return
        }

        val authenticators = authenticatorsFor(allowDeviceCredential)
        val status = try {
            BiometricManager.from(activity).canAuthenticate(authenticators)
        } catch (_: Exception) {
            BiometricManager.BIOMETRIC_STATUS_UNKNOWN
        }
        when (status) {
            BiometricManager.BIOMETRIC_SUCCESS,
            BiometricManager.BIOMETRIC_STATUS_UNKNOWN -> Unit
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> {
                if (allowDeviceCredential) {
                    result.error(
                        PASSCODE_NOT_SET,
                        "No biometrics enrolled and no screen lock is set",
                        null,
                    )
                } else {
                    result.error(NOT_ENROLLED, "No biometrics are enrolled", null)
                }
                return
            }
            else -> {
                result.error(NOT_AVAILABLE, "Biometric authentication is not available", null)
                return
            }
        }

        val promptInfo = try {
            val builder = BiometricPrompt.PromptInfo.Builder()
                .setTitle(reason)
                .setConfirmationRequired(false)
                .setAllowedAuthenticators(authenticators)
            // A negative button is mandatory without device credential and
            // forbidden with it.
            if (!allowDeviceCredential) {
                builder.setNegativeButtonText(
                    if (cancelLabel.isNullOrBlank()) "Cancel" else cancelLabel
                )
            }
            builder.build()
        } catch (e: Exception) {
            result.error("INVALID_ARGS", e.message ?: "Invalid prompt configuration", null)
            return
        }

        pendingResult = result
        try {
            val prompt = BiometricPrompt(
                activity,
                ContextCompat.getMainExecutor(activity),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        authResult: BiometricPrompt.AuthenticationResult,
                    ) {
                        complete { it.success(true) }
                    }

                    override fun onAuthenticationError(code: Int, message: CharSequence) {
                        complete { reply -> replyForError(reply, code, message.toString()) }
                    }

                    // onAuthenticationFailed (a non-matching attempt) is not
                    // terminal: the prompt stays open for another try.
                },
            )
            prompt.authenticate(promptInfo)
        } catch (e: Exception) {
            complete { it.error(GENERIC, e.message ?: "Could not start authentication", null) }
        }
    }

    private fun replyForError(reply: Result, code: Int, message: String) {
        when (code) {
            BiometricPrompt.ERROR_USER_CANCELED,
            BiometricPrompt.ERROR_NEGATIVE_BUTTON,
            BiometricPrompt.ERROR_CANCELED -> reply.success(false)
            BiometricPrompt.ERROR_LOCKOUT,
            BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> reply.error(LOCKED_OUT, message, null)
            BiometricPrompt.ERROR_NO_BIOMETRICS -> reply.error(NOT_ENROLLED, message, null)
            BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL ->
                reply.error(PASSCODE_NOT_SET, message, null)
            BiometricPrompt.ERROR_HW_NOT_PRESENT,
            BiometricPrompt.ERROR_HW_UNAVAILABLE -> reply.error(NOT_AVAILABLE, message, null)
            else -> reply.error(GENERIC, message, code)
        }
    }

    /** Replies exactly once, whatever the prompt does afterwards. */
    private fun complete(block: (Result) -> Unit) {
        val reply = pendingResult ?: return
        pendingResult = null
        try {
            block(reply)
        } catch (_: Exception) {
            // Engine detached while the prompt was showing.
        }
    }

    private fun authenticatorsFor(allowDeviceCredential: Boolean): Int {
        if (!allowDeviceCredential) return Authenticators.BIOMETRIC_STRONG
        // BIOMETRIC_STRONG | DEVICE_CREDENTIAL is only supported from API 30.
        return if (Build.VERSION.SDK_INT >= 30) {
            Authenticators.BIOMETRIC_STRONG or Authenticators.DEVICE_CREDENTIAL
        } else {
            Authenticators.BIOMETRIC_WEAK or Authenticators.DEVICE_CREDENTIAL
        }
    }

    private fun biometricType(context: Context): String {
        val pm = context.packageManager
        val kinds = mutableListOf<String>()
        if (pm.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)) kinds.add("fingerprint")
        if (Build.VERSION.SDK_INT >= 29) {
            if (pm.hasSystemFeature(PackageManager.FEATURE_FACE)) kinds.add("face")
            if (pm.hasSystemFeature(PackageManager.FEATURE_IRIS)) kinds.add("iris")
        }
        return if (kinds.size == 1) kinds[0] else "generic"
    }

    private companion object {
        const val NOT_AVAILABLE = "BIOMETRIC_NOT_AVAILABLE"
        const val NOT_ENROLLED = "BIOMETRIC_NOT_ENROLLED"
        const val LOCKED_OUT = "BIOMETRIC_LOCKED_OUT"
        const val PASSCODE_NOT_SET = "BIOMETRIC_PASSCODE_NOT_SET"
        const val IN_PROGRESS = "BIOMETRIC_IN_PROGRESS"
        const val GENERIC = "BIOMETRIC_ERROR"
    }
}
