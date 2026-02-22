package com.securebankkit.flutter_security_suite.handlers

import java.io.File

/**
 * Detects whether the Android device is rooted.
 *
 * Checks: su binaries, dangerous apps, test-keys in build tags.
 */
class RootDetectionHandler {

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
        return packages.any { pkg ->
            try {
                Runtime.getRuntime().exec("pm list packages $pkg")
                    .inputStream.bufferedReader().readText().contains(pkg)
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun checkTestKeys(): Boolean {
        val buildTags = android.os.Build.TAGS
        return buildTags != null && buildTags.contains("test-keys")
    }
}
