package com.securebankkit.flutter_security_suite.handlers

import android.content.Context
import android.hardware.display.DisplayManager

/**
 * Detects whether the Android screen is currently being mirrored or cast.
 *
 * Strategy:
 * - Checks [DisplayManager] for active Presentation displays, which are
 *   created by screen-casting and mirroring apps (Chromecast, Miracast, etc.).
 *
 * Limitations:
 * - Local file screen recording (e.g. the built-in recorder writing to MP4)
 *   cannot be reliably detected at the application level without system
 *   privileges. Enabling FLAG_SECURE (ScreenshotHandler) is the recommended
 *   mitigation for sensitive screens.
 */
class ScreenRecordingDetectionHandler {

    fun isScreenBeingRecorded(context: Context): Boolean {
        val dm = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        // Presentation displays are virtual displays created for casting/mirroring.
        return dm.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).isNotEmpty()
    }
}
