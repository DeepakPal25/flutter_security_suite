package com.securebankkit.flutter_security_suite.handlers

import android.os.Debug
import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Detects active runtime instrumentation frameworks (Frida, Xposed).
 *
 * Checks:
 * - Java debugger attachment ([Debug.isDebuggerConnected])
 * - Frida default server port (27042) on localhost
 * - `/proc/self/maps` for Frida gadget / agent shared libraries
 * - Xposed framework files on disk
 */
class RuntimeProtectionHandler {

    fun isRuntimeHooked(): Boolean {
        return checkDebuggerAttached()
            || checkFridaPort()
            || checkProcessMaps()
            || checkXposedFiles()
    }

    private fun checkDebuggerAttached(): Boolean = Debug.isDebuggerConnected()

    /**
     * Tries to open a TCP socket to the default Frida server port.
     * A successful connection means `frida-server` is running on the device.
     */
    private fun checkFridaPort(): Boolean {
        return try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress("127.0.0.1", 27042), 100)
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Scans `/proc/self/maps` for shared libraries associated with Frida
     * gadget, Frida agent, and linjector.
     */
    private fun checkProcessMaps(): Boolean {
        val suspicious = listOf("frida", "gadget", "linjector")
        return try {
            BufferedReader(FileReader("/proc/self/maps")).use { reader ->
                reader.lineSequence().any { line ->
                    suspicious.any { lib -> line.lowercase().contains(lib) }
                }
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun checkXposedFiles(): Boolean {
        val xposedPaths = listOf(
            "/system/framework/XposedBridge.jar",
            "/system/bin/app_process_xposed",
            "/system/lib/libxposed_art.so"
        )
        return xposedPaths.any { File(it).exists() }
    }
}
