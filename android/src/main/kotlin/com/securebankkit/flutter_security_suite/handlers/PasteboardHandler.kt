package com.securebankkit.flutter_security_suite.handlers

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import java.util.UUID

/**
 * Clipboard helper for sensitive values.
 *
 * - Marks the clip as sensitive (API 33+) so the system hides it from the
 *   clipboard preview overlay.
 * - Clears the clip after the requested expiry, but only if it is still the
 *   clip written by this plugin (a later copy by the user is left alone).
 *
 * Limitation: from Android 10 an app can only touch the clipboard while it
 * has input focus. If the expiry fires while the app is in the background the
 * clear is retried once the next clipboard call is made in the foreground;
 * Android 13+ additionally auto-clears the clipboard after about an hour.
 *
 * All methods must be called on the main thread.
 */
class PasteboardHandler(private val context: Context) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var ownedLabel: String? = null
    private var pendingClear: Runnable? = null

    /** Throws [IllegalStateException] when the clipboard service is unavailable. */
    fun copy(value: String, expiresAfterMs: Long) {
        val clipboard = clipboard()
            ?: throw IllegalStateException("Clipboard service is not available")

        cancelPendingClear()

        val label = "sbk-" + UUID.randomUUID().toString()
        val clip = ClipData.newPlainText(label, value)
        if (Build.VERSION.SDK_INT >= 24) {
            val extras = PersistableBundle()
            // ClipDescription.EXTRA_IS_SENSITIVE; honoured from API 33 and
            // ignored by older releases.
            extras.putBoolean("android.content.extra.IS_SENSITIVE", true)
            clip.description.extras = extras
        }
        clipboard.setPrimaryClip(clip)
        ownedLabel = label

        val clear = Runnable {
            pendingClear = null
            clear(onlyIfOwned = true)
        }
        pendingClear = clear
        mainHandler.postDelayed(clear, expiresAfterMs)
    }

    /**
     * Clears the clipboard and returns `true` when it was cleared.
     *
     * With [onlyIfOwned] the clipboard is left untouched (and `false` is
     * returned) when it verifiably holds something this plugin did not write.
     */
    fun clear(onlyIfOwned: Boolean): Boolean {
        val clipboard = clipboard() ?: return false
        if (onlyIfOwned) {
            val owned = ownedLabel ?: return false
            val description = try {
                clipboard.primaryClipDescription
            } catch (_: Exception) {
                null
            }
            // A null description means either an empty clipboard or that the
            // app is unfocused and may not look. Clearing is the safe choice
            // in both cases; only a readable foreign clip is preserved.
            if (description != null && description.label?.toString() != owned) {
                ownedLabel = null
                return false
            }
        }
        cancelPendingClear()
        return try {
            if (Build.VERSION.SDK_INT >= 28) {
                clipboard.clearPrimaryClip()
            } else {
                clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
            }
            ownedLabel = null
            true
        } catch (_: Exception) {
            false
        }
    }

    /** Cancels a scheduled clear. Called when the engine detaches. */
    fun dispose() {
        cancelPendingClear()
    }

    private fun cancelPendingClear() {
        pendingClear?.let { mainHandler.removeCallbacks(it) }
        pendingClear = null
    }

    private fun clipboard(): ClipboardManager? =
        context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
}
