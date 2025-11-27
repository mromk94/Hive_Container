package com.example.omk_container_mobile

import android.app.Service
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.IBinder

class ClipboardWatcherService : Service() {

    private var clipboardManager: ClipboardManager? = null
    private var listener: ClipboardManager.OnPrimaryClipChangedListener? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        val mgr = clipboardManager ?: return
        listener = ClipboardManager.OnPrimaryClipChangedListener {
            handleClipboardChanged()
        }
        listener?.let { mgr.addPrimaryClipChangedListener(it) }
    }

    override fun onDestroy() {
        super.onDestroy()
        val mgr = clipboardManager
        val l = listener
        if (mgr != null && l != null) {
            mgr.removePrimaryClipChangedListener(l)
        }
        listener = null
        clipboardManager = null
    }

    private fun handleClipboardChanged() {
        val mgr = clipboardManager ?: return
        val clip: ClipData = mgr.primaryClip ?: return
        if (clip.itemCount == 0) return
        val text = clip.getItemAt(0).coerceToText(this)?.toString() ?: return
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return

        if (!looksLikeSupportedChatUrl(trimmed)) return

        // Debounce: avoid re-triggering for the same value repeatedly.
        val prefs = getSharedPreferences("omk_clipboard", Context.MODE_PRIVATE)
        val lastHash = prefs.getString("last_hash", null)
        val lastTime = prefs.getLong("last_time", 0L)
        val now = System.currentTimeMillis()
        val currentHash = trimmed.hashCode().toString()
        if (lastHash == currentHash && now - lastTime < 20 * 60 * 1000) {
            return
        }
        prefs.edit()
            .putString("last_hash", currentHash)
            .putLong("last_time", now)
            .apply()

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("omk.import_url", trimmed)
        }
        startActivity(intent)
    }

    private fun looksLikeSupportedChatUrl(value: String): Boolean {
        val lower = value.lowercase()
        return lower.contains("chat.openai.com") ||
                lower.contains("chatgpt.com") ||
                lower.contains("g.co/bard") ||
                lower.contains("g.co/gemini") ||
                lower.contains("gemini.google.com") ||
                lower.contains("claude.ai") ||
                lower.contains("grok.com") ||
                (lower.contains("huggingface.co") && lower.contains("/chat")) ||
                lower.contains("poe.com") ||
                lower.contains("perplexity.ai") ||
                lower.contains("deepseek.com") ||
                lower.contains("copilot.microsoft.com") ||
                lower.contains("bing.com/chat")
    }

    companion object {
        fun start(context: Context) {
            val intent = Intent(context, ClipboardWatcherService::class.java)
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, ClipboardWatcherService::class.java)
            context.stopService(intent)
        }
    }
}
