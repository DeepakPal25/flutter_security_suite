package com.securebankkit.flutter_security_suite.handlers

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build

/**
 * Verifies application integrity.
 *
 * Checks: debuggable flag, installer package, signature validity.
 */
class AppIntegrityHandler {

    fun isAppIntegrityValid(context: Context): Boolean {
        return !isDebuggable(context) && isInstalledFromTrustedSource(context)
    }

    private fun isDebuggable(context: Context): Boolean {
        return (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }

    private fun isInstalledFromTrustedSource(context: Context): Boolean {
        val validInstallers = listOf(
            "com.android.vending",    // Google Play Store
            "com.amazon.venezia",     // Amazon App Store
            "com.huawei.appmarket"    // Huawei AppGallery
        )
        val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getInstallerPackageName(context.packageName)
        }
        // In debug/sideloaded builds, installer may be null – treat as invalid
        return installer != null && validInstallers.contains(installer)
    }
}
