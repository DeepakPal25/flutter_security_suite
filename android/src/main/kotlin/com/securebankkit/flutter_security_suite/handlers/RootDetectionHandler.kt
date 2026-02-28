package com.securebankkit.flutter_security_suite.handlers

import android.content.Context
import android.content.pm.PackageManager
import java.io.File

/**
 * Detects whether the Android device is rooted.
 *
 * Checks: su binaries, dangerous apps (via PackageManager), test-keys in
 * build tags.
 *
 * Note: On Android 11+ (API 30+) the root-related package names must be
 * declared in the app's merged AndroidManifest.xml under <queries>. The
 * library's AndroidManifest already includes these declarations, which are
 * merged automatically by the Gradle build system.
 */
class RootDetectionHandler(private val context: Context) {

    fun isDeviceRooted(): Boolean {
        return checkSuBinaries() || checkDangerousApps() || checkTestKeys()
    }

    private fun checkSuBinaries(): Boolean {
        val paths = listOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su"
        )
        return paths.any { File(it).exists() }
    }

    private fun checkDangerousApps(): Boolean {
        val packages = listOf(
            "com.noshufou.android.su",
            "com.noshufou.android.su.elite",
            "eu.chainfire.supersu",
            "com.koushikdutta.superuser",
            "com.thirdparty.superuser",
            "com.yellowes.su",
            "com.topjohnwu.magisk"
        )
        val pm = context.packageManager
        return packages.any { pkg ->
            try {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(pkg, 0)
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }
        }
    }

    private fun checkTestKeys(): Boolean {
        val buildTags = android.os.Build.TAGS
        return buildTags != null && buildTags.contains("test-keys")
    }
}
