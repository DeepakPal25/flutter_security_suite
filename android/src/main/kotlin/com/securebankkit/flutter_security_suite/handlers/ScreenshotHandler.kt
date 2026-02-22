package com.securebankkit.flutter_security_suite.handlers

import android.app.Activity
import android.view.WindowManager

/**
 * Manages screenshot protection using FLAG_SECURE.
 */
class ScreenshotHandler {

    fun enable(activity: Activity?) {
        activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    fun disable(activity: Activity?) {
        activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
