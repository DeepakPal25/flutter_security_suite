package com.securebankkit.flutter_security_suite.handlers

import android.app.Activity
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Streams screen-capture events to Dart.
 *
 * Events:
 * - `{"type": "captureChanged", "isCaptured": Boolean}` when casting or
 *   mirroring starts / stops (a presentation display appears or disappears).
 * - `{"type": "screenshot"}` when the user takes a screenshot. Requires
 *   API 34+ and the `DETECT_SCREEN_CAPTURE` permission (declared by this
 *   plugin's manifest).
 *
 * Limitations: a local screen recording written to a file is not observable
 * by a regular app; use FLAG_SECURE (ScreenshotHandler) for sensitive screens.
 */
class ScreenCaptureHandler(private val context: Context) : EventChannel.StreamHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val displayManager: DisplayManager? =
        context.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager

    private var sink: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private var lastCaptured: Boolean? = null
    private var displayListenerRegistered = false

    // Held as Any so the class still loads on API < 34.
    private var screenshotCallback: Any? = null
    private var screenshotCallbackActivity: Activity? = null

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = emitCaptureState(force = false)
        override fun onDisplayRemoved(displayId: Int) = emitCaptureState(force = false)
        override fun onDisplayChanged(displayId: Int) = emitCaptureState(force = false)
    }

    /** Returns `true` while the screen is being cast or mirrored. */
    fun isCaptured(): Boolean {
        return try {
            displayManager
                ?.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
                ?.isNotEmpty() ?: false
        } catch (_: Exception) {
            false
        }
    }

    /** Must be called whenever the plugin's activity changes (null on detach). */
    fun setActivity(newActivity: Activity?) {
        if (activity === newActivity) return
        unregisterScreenshotCallback()
        activity = newActivity
        if (sink != null) registerScreenshotCallback()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        lastCaptured = null
        if (!displayListenerRegistered) {
            try {
                displayManager?.registerDisplayListener(displayListener, mainHandler)
                displayListenerRegistered = displayManager != null
            } catch (_: Exception) {
                displayListenerRegistered = false
            }
        }
        registerScreenshotCallback()
        // Emit the current state so late subscribers do not miss an
        // already-running cast session.
        emitCaptureState(force = true)
    }

    override fun onCancel(arguments: Any?) {
        dispose()
    }

    /** Releases every listener. Safe to call more than once. */
    fun dispose() {
        sink = null
        lastCaptured = null
        if (displayListenerRegistered) {
            try {
                displayManager?.unregisterDisplayListener(displayListener)
            } catch (_: Exception) {
                // Listener was already gone.
            }
            displayListenerRegistered = false
        }
        unregisterScreenshotCallback()
    }

    private fun emitCaptureState(force: Boolean) {
        val captured = isCaptured()
        if (!force && captured == lastCaptured) return
        lastCaptured = captured
        emit(mapOf("type" to "captureChanged", "isCaptured" to captured))
    }

    private fun emit(event: Map<String, Any>) {
        val post = Runnable {
            try {
                sink?.success(event)
            } catch (_: Exception) {
                // Engine is shutting down; nothing to deliver to.
            }
        }
        if (Looper.myLooper() == Looper.getMainLooper()) post.run() else mainHandler.post(post)
    }

    private fun registerScreenshotCallback() {
        if (Build.VERSION.SDK_INT < 34) return
        val current = activity ?: return
        if (screenshotCallback != null) return
        try {
            val callback = Activity.ScreenCaptureCallback {
                emit(mapOf("type" to "screenshot"))
            }
            current.registerScreenCaptureCallback(current.mainExecutor, callback)
            screenshotCallback = callback
            screenshotCallbackActivity = current
        } catch (_: Exception) {
            // SecurityException when the host app stripped the
            // DETECT_SCREEN_CAPTURE permission: screenshots are simply not
            // reported; capture-state events keep working.
            screenshotCallback = null
            screenshotCallbackActivity = null
        }
    }

    private fun unregisterScreenshotCallback() {
        val callback = screenshotCallback
        val owner = screenshotCallbackActivity
        screenshotCallback = null
        screenshotCallbackActivity = null
        if (Build.VERSION.SDK_INT < 34 || callback == null || owner == null) return
        try {
            owner.unregisterScreenCaptureCallback(callback as Activity.ScreenCaptureCallback)
        } catch (_: Exception) {
            // Activity already destroyed.
        }
    }
}
