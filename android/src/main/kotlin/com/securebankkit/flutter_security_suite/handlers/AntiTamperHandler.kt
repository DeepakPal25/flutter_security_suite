package com.securebankkit.flutter_security_suite.handlers

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Debug
import java.io.File

/**
 * Anti-tamper checks: debugger attachment and injected native libraries.
 *
 * Every check is wrapped so that an unreadable /proc entry or a restricted
 * environment yields `false` for that single signal instead of crashing.
 */
class AntiTamperHandler {

    /**
     * Returns `true` when a JDWP debugger is connected (or the process is
     * waiting for one), or when a native tracer (ptrace / gdb / lldb / strace)
     * is attached according to `/proc/self/status`.
     */
    fun isDebuggerAttached(): Boolean {
        return Debug.isDebuggerConnected()
            || Debug.waitingForDebugger()
            || tracerPid() > 0
    }

    /**
     * Returns `true` when a library appears to have been injected into the
     * process: `LD_PRELOAD` is set, or `/proc/self/maps` lists a known
     * instrumentation library.
     */
    fun hasInjectedLibraries(): Boolean {
        return hasPreloadedLibrary() || hasSuspiciousMapping()
    }

    /**
     * Android has no `PT_DENY_ATTACH` equivalent. Debugger attachment is
     * denied by the OS for every app that is not `android:debuggable`, so this
     * reports whether that guarantee holds for the running build.
     */
    fun denyDebugger(context: Context): Boolean {
        val debuggable =
            (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        return !debuggable && !isDebuggerAttached()
    }

    private fun tracerPid(): Int {
        return try {
            File("/proc/self/status").useLines { lines ->
                lines.firstOrNull { it.startsWith("TracerPid:") }
                    ?.substringAfter(':')
                    ?.trim()
                    ?.toIntOrNull() ?: 0
            }
        } catch (_: Exception) {
            0
        }
    }

    private fun hasPreloadedLibrary(): Boolean {
        return try {
            !System.getenv("LD_PRELOAD").isNullOrBlank()
        } catch (_: Exception) {
            false
        }
    }

    private fun hasSuspiciousMapping(): Boolean {
        return try {
            File("/proc/self/maps").useLines { lines ->
                lines.any { line ->
                    val lower = line.lowercase()
                    SUSPICIOUS_LIBRARIES.any { lower.contains(it) }
                }
            }
        } catch (_: Exception) {
            false
        }
    }

    private companion object {
        val SUSPICIOUS_LIBRARIES = listOf(
            "frida",
            "libgadget",
            "linjector",
            "libsubstrate",
            "substrate-dvm",
            "libxposed",
            "xposedbridge",
            "edxposed",
            "lsposed",
            "libriru",
            "libdobby",
            "libsandhook",
            "libwhale",
        )
    }
}
