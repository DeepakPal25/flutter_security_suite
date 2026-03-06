package com.securebankkit.flutter_security_suite.handlers

import android.os.Build
import java.io.File

/**
 * Detects whether the app is running on an Android emulator or virtual device.
 *
 * Checks:
 * - Build properties (fingerprint, model, manufacturer, hardware, product)
 *   associated with AOSP emulators, Genymotion, and BlueStacks.
 * - Emulator-specific system files (QEMU device nodes).
 */
class EmulatorDetectionHandler {

    fun isEmulator(): Boolean {
        return checkBuildProperties() || checkEmulatorFiles()
    }

    private fun checkBuildProperties(): Boolean {
        val fingerprint  = Build.FINGERPRINT.lowercase()
        val model        = Build.MODEL.lowercase()
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand        = Build.BRAND.lowercase()
        val device       = Build.DEVICE.lowercase()
        val hardware     = Build.HARDWARE.lowercase()
        val product      = Build.PRODUCT.lowercase()

        return fingerprint.contains("generic")
            || fingerprint.contains("unknown")
            || fingerprint.startsWith("sdk")
            || model.contains("google_sdk")
            || model.contains("emulator")
            || model.contains("android sdk built for")
            || manufacturer.contains("genymotion")
            || brand.startsWith("generic")
            || device.contains("emulator")
            || hardware == "goldfish"           // AOSP QEMU 1
            || hardware == "ranchu"             // AOSP QEMU 2
            || product.contains("sdk_gphone")  // Google API image
            || product.contains("vbox86p")     // Genymotion
            || product.contains("emulator")
            || product.contains("simulator")
    }

    private fun checkEmulatorFiles(): Boolean {
        val files = listOf(
            "/dev/socket/qemud",
            "/dev/qemu_pipe",
            "/system/lib/libc_malloc_debug_qemu.so",
            "/sys/qemu_trace",
            "/system/bin/qemu-props"
        )
        return files.any { File(it).exists() }
    }
}
