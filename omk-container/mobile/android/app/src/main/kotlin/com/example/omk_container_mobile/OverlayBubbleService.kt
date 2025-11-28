package com.example.omk_container_mobile

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.AlphaAnimation
import android.view.animation.Animation
import android.view.animation.AnimationSet
import android.view.animation.DecelerateInterpolator
import android.view.animation.ScaleAnimation
import android.widget.EditText
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import kotlin.math.abs
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.net.HttpURLConnection
import java.net.URL
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class OverlayBubbleService : Service() {

    private lateinit var windowManager: WindowManager
    private lateinit var mainHandler: Handler
    private var bubbleView: View? = null
    private var assistantView: View? = null
    private lateinit var params: WindowManager.LayoutParams

    private val messages = mutableListOf<OverlayMessage>()
    private var isDarkTheme: Boolean = true
    private val queenBaseUrl: String =
        "https://omk-queen-ai-475745165557.us-central1.run.app"

    private val costPerKTokens: Map<String, Double> = mapOf(
        "gpt" to 0.01,
        "claude" to 0.011,
        "gemini" to 0.009,
        "grok" to 0.009,
        "deepseek" to 0.006,
        "local" to 0.0,
    )

    private val systemPrompt: String =
        "You are OMK, a protective personal hive assistant. Answer the user in clear, natural language. " +
            "Do not include debug metadata, tool lists, context counts, or persona headers. " +
            "Never wrap replies in brackets or curly braces; just speak to the human directly."

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Log.d("OverlayBubbleService", "onCreate")
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        mainHandler = Handler(Looper.getMainLooper())
        // Initialise theme from the same shared preference as Flutter.
        isDarkTheme = loadThemeFromPrefs()
        addBubble()
    }

    override fun onDestroy() {
        super.onDestroy()
        bubbleView?.let { windowManager.removeView(it) }
        bubbleView = null
        assistantView?.let { windowManager.removeView(it) }
        assistantView = null
    }

    private fun addBubble() {
        if (bubbleView != null) return

        Log.d("OverlayBubbleService", "addBubble")

        val inflater = LayoutInflater.from(this)
        val view = inflater.inflate(R.layout.overlay_bubble, null)

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val bubbleSize = (64 * resources.displayMetrics.density).toInt()

        params = WindowManager.LayoutParams(
            bubbleSize,
            bubbleSize,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP or Gravity.START
        params.x = 0
        params.y = 400

        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f

        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (event.rawX - initialTouchX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    windowManager.updateViewLayout(view, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val dx = abs(event.rawX - initialTouchX)
                    val dy = abs(event.rawY - initialTouchY)
                    // Treat as a tap if finger didn't move far; trigger click.
                    if (dx < 10 && dy < 10) {
                        view.performClick()
                    }
                    true
                }
                else -> false
            }
        }

        view.setOnClickListener {
            toggleAssistantOverlay()
        }

        windowManager.addView(view, params)
        bubbleView = view
    }

    private fun toggleAssistantOverlay() {
        if (assistantView != null) {
            assistantView?.let { windowManager.removeView(it) }
            assistantView = null
            return
        }

        val inflater = LayoutInflater.from(this)
        val view = inflater.inflate(R.layout.overlay_assistant, null)

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val assistantParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )

        assistantParams.gravity = Gravity.TOP or Gravity.START

        val root = view.findViewById<View>(R.id.assistant_root)
        val messagesContainer = view.findViewById<LinearLayout>(R.id.messages_container)
        val messagesScroll = view.findViewById<ScrollView>(R.id.messages_scroll)
        val inputField = view.findViewById<EditText>(R.id.input_field)
        val sendButton = view.findViewById<ImageButton>(R.id.send_button)
        val closeButton = view.findViewById<View>(R.id.assistant_close)
        val themeToggle = view.findViewById<ImageButton>(R.id.theme_toggle)
        val titleView = view.findViewById<TextView>(R.id.assistant_title)
        val scanButton = view.findViewById<ImageButton>(R.id.scan_button)
        val chipAnalyze = view.findViewById<TextView>(R.id.chip_analyze)
        val chipSummarize = view.findViewById<TextView>(R.id.chip_summarize)
        val chipGuard = view.findViewById<TextView>(R.id.chip_guard)
        val statusCloud = view.findViewById<TextView>(R.id.status_cloud)
        val iconView = view.findViewById<View>(R.id.assistant_icon)
        loadMessagesFromPrefs()

        applyTheme(root, titleView, inputField, themeToggle)
        renderMessages(messagesContainer, messagesScroll)

        sendButton.setOnClickListener {
            val text = inputField.text?.toString()?.trim().orEmpty()
            if (text.isEmpty()) return@setOnClickListener
            inputField.text?.clear()
            // Record the user message into the shared history and then
            // call the Queen-backed brain directly from the overlay.
            messages.add(OverlayMessage(text = text, isUser = true))
            saveMessagesToPrefs()
            renderMessages(messagesContainer, messagesScroll)

            // Show a short thinking bubble while we wait for Queen.
            messages.add(OverlayMessage(text = "Thinking…", isUser = false))
            renderMessages(messagesContainer, messagesScroll)

            requestQueenReply { reply, insufficientCost ->
                // Remove the transient thinking bubble if present.
                if (messages.isNotEmpty()) {
                    val last = messages.last()
                    if (!last.isUser && last.text.startsWith("Thinking")) {
                        messages.removeAt(messages.size - 1)
                    }
                }

                val finalText = when {
                    insufficientCost != null ->
                        "Not enough OMK to call the cloud model (needs ~$insufficientCost OMK). Open OMK to top up."
                    reply.isNullOrBlank() ->
                        "OMK could not reply right now."
                    else -> reply.trim()
                }
                messages.add(OverlayMessage(text = finalText, isUser = false))
                saveMessagesToPrefs()
                renderMessages(messagesContainer, messagesScroll)
            }
        }

        themeToggle.setOnClickListener {
            isDarkTheme = !isDarkTheme
            saveThemeToPrefs()
            applyTheme(root, titleView, inputField, themeToggle)
        }

        closeButton.setOnClickListener {
            assistantView?.let { windowManager.removeView(it) }
            assistantView = null
        }

        // Tap outside card closes the assistant.
        view.setOnClickListener {
            assistantView?.let { windowManager.removeView(it) }
            assistantView = null
        }
        // Consume taps on the card so they don't bubble to the backdrop.
        root.setOnClickListener { /* no-op: eat event */ }

        chipAnalyze.setOnClickListener {
            messages.add(OverlayMessage(text = "Analyze this screen", isUser = true))
            saveMessagesToPrefs()
            renderMessages(messagesContainer, messagesScroll)

            messages.add(OverlayMessage(text = "Thinking…", isUser = false))
            renderMessages(messagesContainer, messagesScroll)

            requestQueenReply { reply, insufficientCost ->
                if (messages.isNotEmpty()) {
                    val last = messages.last()
                    if (!last.isUser && last.text.startsWith("Thinking")) {
                        messages.removeAt(messages.size - 1)
                    }
                }

                val finalText = when {
                    insufficientCost != null ->
                        "Not enough OMK to analyze this screen (needs ~$insufficientCost OMK). Open OMK to top up."
                    reply.isNullOrBlank() ->
                        "Analyze failed in this build."
                    else -> reply.trim()
                }
                messages.add(OverlayMessage(text = finalText, isUser = false))
                saveMessagesToPrefs()
                renderMessages(messagesContainer, messagesScroll)
            }
        }

        chipSummarize.setOnClickListener {
            messages.add(OverlayMessage(text = "Summarize this page", isUser = true))
            saveMessagesToPrefs()
            renderMessages(messagesContainer, messagesScroll)

            messages.add(OverlayMessage(text = "Thinking…", isUser = false))
            renderMessages(messagesContainer, messagesScroll)

            requestQueenReply { reply, insufficientCost ->
                if (messages.isNotEmpty()) {
                    val last = messages.last()
                    if (!last.isUser && last.text.startsWith("Thinking")) {
                        messages.removeAt(messages.size - 1)
                    }
                }

                val finalText = when {
                    insufficientCost != null ->
                        "Not enough OMK to summarize this page (needs ~$insufficientCost OMK). Open OMK to top up."
                    reply.isNullOrBlank() ->
                        "Summarize failed in this build."
                    else -> reply.trim()
                }
                messages.add(OverlayMessage(text = finalText, isUser = false))
                saveMessagesToPrefs()
                renderMessages(messagesContainer, messagesScroll)
            }
        }

        chipGuard.setOnClickListener {
            messages.add(OverlayMessage(text = "Guard me on this site", isUser = true))
            saveMessagesToPrefs()
            renderMessages(messagesContainer, messagesScroll)

            messages.add(OverlayMessage(text = "Thinking…", isUser = false))
            renderMessages(messagesContainer, messagesScroll)

            requestQueenReply { reply, insufficientCost ->
                if (messages.isNotEmpty()) {
                    val last = messages.last()
                    if (!last.isUser && last.text.startsWith("Thinking")) {
                        messages.removeAt(messages.size - 1)
                    }
                }

                val finalText = when {
                    insufficientCost != null ->
                        "Not enough OMK to run Guard Me (needs ~$insufficientCost OMK). Open OMK to top up."
                    reply.isNullOrBlank() ->
                        "Guard Me could not start in this build."
                    else -> reply.trim()
                }
                messages.add(OverlayMessage(text = finalText, isUser = false))
                saveMessagesToPrefs()
                renderMessages(messagesContainer, messagesScroll)
            }
        }

        startBreathingAnimations(iconView, sendButton, scanButton, chipAnalyze, chipSummarize, chipGuard)
        startPulse(statusCloud)

        val animationSet = AnimationSet(true).apply {
            interpolator = DecelerateInterpolator()
            duration = 200
            addAnimation(AlphaAnimation(0f, 1f))
            addAnimation(ScaleAnimation(
                0.9f,
                1f,
                0.9f,
                1f,
                AnimationSet.RELATIVE_TO_SELF,
                0.5f,
                AnimationSet.RELATIVE_TO_SELF,
                0.5f,
            ))
        }

        windowManager.addView(view, assistantParams)
        root.startAnimation(animationSet)
        assistantView = view
    }

    private fun renderMessages(container: LinearLayout, scroll: ScrollView) {
        container.removeAllViews()
        for (message in messages) {
            val bubble = TextView(this).apply {
                text = message.text
                setTextColor(if (message.isUser) 0xFF000000.toInt() else 0xFFFFFFFF.toInt())
                textSize = 14f
                setPadding(24, 16, 24, 16)
                background = resources.getDrawable(
                    if (message.isUser) R.drawable.overlay_message_user else R.drawable.overlay_message_assistant,
                    null,
                )
                setShadowLayer(6f, 0f, 3f, 0x80000000.toInt())
                val params = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                )
                params.setMargins(16, 8, 16, 8)
                params.gravity = if (message.isUser) Gravity.END else Gravity.START
                layoutParams = params
            }
            container.addView(bubble)
        }
        scroll.post { scroll.fullScroll(View.FOCUS_DOWN) }
    }

    private fun applyTheme(root: View, title: TextView, input: EditText, themeToggle: ImageButton) {
        if (isDarkTheme) {
            root.setBackgroundResource(R.drawable.overlay_assistant_background_dark)
            title.setTextColor(0xFFFFFFFF.toInt())
            input.setTextColor(0xFFFFFFFF.toInt())
            input.setHintTextColor(0x99FFFFFF.toInt())
            input.setBackgroundResource(R.drawable.overlay_input_background_dark)
            themeToggle.setBackgroundResource(R.drawable.overlay_theme_moon)
        } else {
            root.setBackgroundResource(R.drawable.overlay_assistant_background_light)
            title.setTextColor(0xFF000000.toInt())
            input.setTextColor(0xFF000000.toInt())
            input.setHintTextColor(0x99000000.toInt())
            input.setBackgroundResource(R.drawable.overlay_input_background_light)
            themeToggle.setBackgroundResource(R.drawable.overlay_theme_sun)
        }
    }

    private fun startBreathingAnimations(vararg views: View) {
        views.forEach { view ->
            val anim = ScaleAnimation(
                0.96f,
                1.04f,
                0.96f,
                1.04f,
                Animation.RELATIVE_TO_SELF,
                0.5f,
                Animation.RELATIVE_TO_SELF,
                0.5f,
            ).apply {
                duration = 2200
                repeatMode = Animation.REVERSE
                repeatCount = Animation.INFINITE
                interpolator = DecelerateInterpolator()
            }
            view.startAnimation(anim)
        }
    }

    private fun startPulse(view: View) {
        val anim = AlphaAnimation(0.6f, 1f).apply {
            duration = 1600
            repeatMode = Animation.REVERSE
            repeatCount = Animation.INFINITE
            interpolator = DecelerateInterpolator()
        }
        view.startAnimation(anim)
    }

    private fun loadThemeFromPrefs(): Boolean {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            // Mirrors ThemeStore._key in Flutter (stored as flutter.omk_theme_dark_v1)
            prefs.getBoolean("flutter.omk_theme_dark_v1", true)
        } catch (e: Exception) {
            Log.e("OverlayBubbleService", "Failed to load theme pref", e)
            true
        }
    }

    private fun saveThemeToPrefs() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.omk_theme_dark_v1", isDarkTheme).apply()
        } catch (e: Exception) {
            Log.e("OverlayBubbleService", "Failed to save theme pref", e)
        }
    }

    private fun loadMessagesFromPrefs() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val json = prefs.getString("flutter.omk_chat_history_v1", null) ?: return
            val arr = JSONArray(json)
            messages.clear()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val role = obj.optString("role", "user")
                val text = obj.optString("text", "")
                val isUser = role == "user"
                // Drop any legacy stub messages from early builds so
                // they don't pollute the current chat overlay.
                if (text.contains("stub", ignoreCase = true)) {
                    continue
                }
                messages.add(OverlayMessage(text = text, isUser = isUser))
            }
        } catch (e: Exception) {
            Log.e("OverlayBubbleService", "Failed to load chat history", e)
        }
    }

    private fun saveMessagesToPrefs() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val arr = JSONArray()
            for (message in messages) {
                val obj = JSONObject()
                obj.put("role", if (message.isUser) "user" else "assistant")
                obj.put("text", message.text)
                arr.put(obj)
            }
            prefs.edit().putString("flutter.omk_chat_history_v1", arr.toString()).apply()
        } catch (e: Exception) {
            Log.e("OverlayBubbleService", "Failed to save chat history", e)
        }
    }

    private fun requestQueenReply(onResult: (String?, String?) -> Unit) {
        Thread {
            try {
                val modelId = "gemini"
                val tokens = estimateTokens()
                val costStr = calculateCostOmk(tokens, modelId)

                val spendOk = spendOmkWithQueen(costStr, "llm_call:$modelId")
                if (!spendOk) {
                    mainHandler.post { onResult(null, costStr) }
                    return@Thread
                }

                val url = URL("$queenBaseUrl/llm/generate")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json; charset=utf-8")
                    doOutput = true
                    connectTimeout = 15000
                    readTimeout = 30000
                }

                val payload = buildQueenPayload(modelId)
                conn.outputStream.use { os ->
                    os.write(payload.toByteArray(Charsets.UTF_8))
                }

                val code = conn.responseCode
                val stream = if (code in 200..299) conn.inputStream else conn.errorStream
                val raw = stream?.bufferedReader()?.use { it.readText() } ?: ""
                val reply = parseQueenReply(raw)

                mainHandler.post { onResult(reply, null) }
            } catch (e: Exception) {
                Log.e("OverlayBubbleService", "Queen request failed", e)
                mainHandler.post { onResult(null, null) }
            }
        }.start()
    }

    private fun buildQueenPayload(modelId: String): String {
        val root = JSONObject()
        root.put("model", modelId)
        val arr = JSONArray()

        // Prepend a system message so Queen returns user-friendly text
        // instead of debug-style metadata blobs.
        val system = JSONObject()
        system.put("role", "system")
        system.put("text", systemPrompt)
        arr.put(system)

        for (m in messages) {
            val obj = JSONObject()
            obj.put("role", if (m.isUser) "user" else "assistant")
            obj.put("text", m.text)
            arr.put(obj)
        }
        root.put("messages", arr)
        return root.toString()
    }

    private fun parseQueenReply(raw: String): String? {
        if (raw.isBlank()) return null
        return try {
            val root = JSONObject(raw)
            val response = root.opt("response")
            when (response) {
                is String -> response.trim().ifEmpty { null }
                is JSONObject -> {
                    val text = response.optString("text", response.optString("content", ""))
                    text.trim().ifEmpty { null }
                }
                else -> null
            }
        } catch (e: Exception) {
            Log.e("OverlayBubbleService", "Failed to parse Queen reply", e)
            null
        }
    }

    private fun estimateTokens(): Int {
        var chars = 0
        for (m in messages) {
            chars += m.text.length
        }
        if (chars == 0) return 64
        var est = chars / 4
        if (est < 64) est = 64
        if (est > 4000) est = 4000
        return est
    }

    private fun calculateCostOmk(tokens: Int, modelId: String): String {
        val perK = costPerKTokens[modelId] ?: 0.01
        val cost = (tokens.toDouble() / 1000.0) * perK
        return String.format(Locale.US, "%.4f", cost)
    }

    private fun spendOmkWithQueen(amountOmk: String, reason: String): Boolean {
        // First, attempt to satisfy the spend purely against the
        // locally cached balance (which may include the 20 OMK
        // welcome bonus written by Flutter) so that fresh installs
        // can actually use their credits even if the backend wallet
        // starts at 0.
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.omk_wallet_balance_v1", null)
            if (!raw.isNullOrBlank()) {
                val obj = JSONObject(raw)
                val balStr = obj.optString("balanceOmk", "0").trim()
                val local = balStr.toDoubleOrNull() ?: 0.0
                val amt = amountOmk.trim().toDoubleOrNull() ?: 0.0
                if (amt > 0.0 && local + 1e-9 >= amt) {
                    val remaining = local - amt
                    persistWalletBalance(String.format(Locale.US, "%.4f", remaining))
                    return true
                }
            }
        } catch (e: Exception) {
            Log.e("OverlayBubbleService", "Local wallet math failed", e)
        }

        // Fallback: ask Queen to perform the spend and treat its
        // response as the source of truth when available.
        return try {
            val url = URL("$queenBaseUrl/wallet/spend")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                doOutput = true
                connectTimeout = 15000
                readTimeout = 30000
            }

            val body = JSONObject().apply {
                put("amountOmk", amountOmk)
                put("reason", reason)
            }
            conn.outputStream.use { os ->
                os.write(body.toString().toByteArray(Charsets.UTF_8))
            }

            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val raw = stream?.bufferedReader()?.use { it.readText() } ?: ""
            if (raw.isBlank()) return false

            val data = JSONObject(raw)
            val success = data.optBoolean("success", false)
            if (!success) return false

            val newBalance = data.optString("balanceOmk", "")
            if (newBalance.isNotBlank()) {
                persistWalletBalance(newBalance)
            }
            true
        } catch (e: Exception) {
            Log.e("OverlayBubbleService", "Wallet spend failed", e)
            false
        }
    }

    private fun persistWalletBalance(balanceOmk: String) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
            val nowIso = fmt.format(Date())
            val obj = JSONObject().apply {
                put("balanceOmk", balanceOmk)
                put("lastUpdated", nowIso)
            }
            prefs.edit()
                .putString("flutter.omk_wallet_balance_v1", obj.toString())
                .apply()
        } catch (e: Exception) {
            Log.e("OverlayBubbleService", "Failed to persist wallet balance", e)
        }
    }

    private fun openMainActivity() {
        try {
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            intent.putExtra("omk.from_overlay", true)
            startActivity(intent)
        } catch (e: Exception) {
            Log.e("OverlayBubbleService", "Failed to open main activity from overlay", e)
        }
    }

    companion object {
        fun start(context: Context) {
            val intent = Intent(context, OverlayBubbleService::class.java)
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, OverlayBubbleService::class.java)
            context.stopService(intent)
        }
    }
}

data class OverlayMessage(val text: String, val isUser: Boolean)
