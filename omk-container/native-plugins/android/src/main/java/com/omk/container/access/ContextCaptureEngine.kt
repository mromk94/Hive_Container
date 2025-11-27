package com.omk.container.access

import android.view.accessibility.AccessibilityWindowInfo

/**
 * Context Capture Engine (CCE)
 *
 * Listens to accessibility-driven screen updates and (in future) foreground
 * app / screenshot events, then maintains a small rolling snapshot of
 * sanitized context for the Neural Switchboard.
 */
object ContextCaptureEngine {

    data class Snapshot(
        val appPackage: String?,
        val appLabel: String?,
        val textSnippets: List<String>,
        val screenshotHash: String?,
    )

    private val lock = Any()
    private var appPackage: String? = null
    private var appLabel: String? = null
    private val textSnippets: ArrayDeque<String> = ArrayDeque()
    private var screenshotHash: String? = null

    private const val MAX_SNIPPETS = 50

    /** Called by OmkAccessibilityService when the window hierarchy changes. */
    fun onAccessibilityWindows(windows: List<AccessibilityWindowInfo>?) {
        val nodes = AccessibilityTextCapture.captureFromWindows(windows)
        if (nodes.isEmpty()) return

        val texts = nodes.map { it.text }.distinct().take(10)
        synchronized(lock) {
            for (t in texts) {
                if (t.isBlank()) continue
                if (textSnippets.contains(t)) continue
                if (textSnippets.size >= MAX_SNIPPETS) {
                    textSnippets.removeFirst()
                }
                textSnippets.addLast(t)
            }
        }
    }

    /** Optional hook for future foreground-app detection. */
    fun setForegroundApp(packageName: String?, label: String?) {
        synchronized(lock) {
            appPackage = packageName
            appLabel = label
        }
    }

    /** Optional hook for future screenshot OCR integration. */
    fun onScreenshotContext(phash: String?, snippets: List<String>) {
        synchronized(lock) {
            screenshotHash = phash
            for (t in snippets) {
                if (t.isBlank()) continue
                if (textSnippets.contains(t)) continue
                if (textSnippets.size >= MAX_SNIPPETS) {
                    textSnippets.removeFirst()
                }
                textSnippets.addLast(t)
            }
        }
    }

    fun clear() {
        synchronized(lock) {
            textSnippets.clear()
            screenshotHash = null
        }
    }

    fun snapshot(): Snapshot {
        synchronized(lock) {
            return Snapshot(
                appPackage = appPackage,
                appLabel = appLabel,
                textSnippets = textSnippets.toList(),
                screenshotHash = screenshotHash,
            )
        }
    }
}
