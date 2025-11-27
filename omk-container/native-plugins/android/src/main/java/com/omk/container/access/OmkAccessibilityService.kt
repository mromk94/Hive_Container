package com.omk.container.access

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent

/**
 * Skeleton AccessibilityService used for on-device context capture.
 *
 * When enabled by the user, this service can capture visible text from the
 * active window when the floating OMK bubble is expanded.
 */
class OmkAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "OmkAccessibilityService connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // In a full implementation, we would coordinate with the Flutter layer
        // to only capture when the bubble is expanded and user has opted-in.
        val currentWindows = windows
        ContextCaptureEngine.onAccessibilityWindows(currentWindows)
    }

    override fun onInterrupt() {
        Log.i(TAG, "OmkAccessibilityService interrupted")
    }

    companion object {
        private const val TAG = "OmkA11ySvc"
    }
}

/**
 * Example manifest entry:
 *
 * <service
 *   android:name=".access.OmkAccessibilityService"
 *   android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"
 *   android:exported="false">
 *   <intent-filter>
 *     <action android:name="android.accessibilityservice.AccessibilityService" />
 *   </intent-filter>
 *   <meta-data
 *     android:name="android.accessibilityservice"
 *     android:resource="@xml/omk_accessibility_config" />
 * </service>
 */
