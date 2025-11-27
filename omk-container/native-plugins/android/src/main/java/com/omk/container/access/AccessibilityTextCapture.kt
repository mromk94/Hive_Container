package com.omk.container.access

import android.graphics.Rect
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import com.omk.container.vpn.SecurityEventLogger

/**
 * Accessibility-based text capture.
 *
 * Traverses the active window hierarchy and extracts visible text nodes with
 * their bounding boxes. A lightweight sanitization step is applied before
 * anything is logged or forwarded.
 */
object AccessibilityTextCapture {

    data class TextNode(
        val text: String,
        val bounds: Rect,
    )

    fun captureFromWindows(windows: List<AccessibilityWindowInfo>?): List<TextNode> {
        if (windows == null) return emptyList()
        val out = mutableListOf<TextNode>()
        for (w in windows) {
            val root = w.root ?: continue
            collectFromNode(root, out)
        }
        // Simple privacy pass before logging
        val sanitized = out.map { node ->
            node.copy(text = PrivacySanitizer.sanitizeForLogging(node.text))
        }
        for (n in sanitized) {
            SecurityEventLogger.logConnection(
                // Reuse connection schema loosely: mark text capture as metadata-only.
                info = com.omk.container.vpn.PacketInfo(
                    sourceIp = "0.0.0.0",
                    sourcePort = 0,
                    destIp = "0.0.0.0",
                    destPort = 0,
                    protocol = "A11Y",
                    isDns = false,
                    isTcp = false,
                    sni = null,
                    rawData = ByteArray(0),
                ),
                payloadBytes = 0,
            )
        }
        return sanitized
    }

    private fun collectFromNode(node: AccessibilityNodeInfo, out: MutableList<TextNode>) {
        val text = (node.text ?: node.contentDescription)?.toString()?.trim()
        if (!text.isNullOrEmpty() && node.isVisibleToUser) {
            val r = Rect()
            node.getBoundsInScreen(r)
            out.add(TextNode(text = text, bounds = r))
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectFromNode(child, out)
        }
    }
}
