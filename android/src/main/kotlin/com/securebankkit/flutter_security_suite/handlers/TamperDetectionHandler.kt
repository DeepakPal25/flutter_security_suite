package com.securebankkit.flutter_security_suite.handlers

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.security.MessageDigest

/**
 * Detects whether the APK has been tampered with or re-signed.
 *
 * Checks:
 * - Whether a signing certificate is present at all (stripped in patched APKs).
 *
 * Additionally exposes [getSigningCertificateHash] so the host app can pin
 * its own expected SHA-256 certificate fingerprint and verify at runtime:
 *
 * ```kotlin
 * val expected = "a1b2c3..."  // SHA-256 hex of your release cert
 * val actual   = handler.getSigningCertificateHash(context)
 * val tampered = actual == null || actual != expected
 * ```
 */
class TamperDetectionHandler {

    /**
     * Returns `true` when basic tampering indicators are found (e.g. missing
     * signing certificate). For full certificate pinning call
     * [getSigningCertificateHash] and compare against your expected value.
     */
    fun isTampered(context: Context): Boolean {
        return !hasValidSignature(context)
    }

    /**
     * Returns the SHA-256 hex fingerprint of the app's signing certificate,
     * or `null` if it cannot be retrieved.
     */
    fun getSigningCertificateHash(context: Context): String? {
        return try {
            val certBytes = getSigningCertBytes(context) ?: return null
            MessageDigest.getInstance("SHA-256")
                .digest(certBytes)
                .joinToString("") { "%02x".format(it) }
        } catch (_: Exception) {
            null
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private fun hasValidSignature(context: Context): Boolean {
        return try {
            getSigningCertBytes(context) != null
        } catch (_: Exception) {
            false
        }
    }

    private fun getSigningCertBytes(context: Context): ByteArray? {
        val pm = context.packageManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = pm.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNING_CERTIFICATES
            )
            info.signingInfo
                ?.signingCertificateHistory
                ?.firstOrNull()
                ?.toByteArray()
        } else {
            @Suppress("DEPRECATION")
            val info = pm.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNATURES
            )
            @Suppress("DEPRECATION")
            info.signatures?.firstOrNull()?.toByteArray()
        }
    }
}
