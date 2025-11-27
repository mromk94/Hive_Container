package com.omk.container.access

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter plugin exposing ContextCaptureEngine snapshots to Dart.
 *
 * Channel: `omk_container/context`
 * Methods:
 * - getSnapshot() -> { appPackage, appLabel, textSnippets, screenshotHash }
 * - clear()
 */
class OmkContextPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var context: Context? = null
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "omk_container/context")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSnapshot" -> {
                val snap = ContextCaptureEngine.snapshot()
                result.success(
                    mapOf(
                        "appPackage" to snap.appPackage,
                        "appLabel" to snap.appLabel,
                        "textSnippets" to snap.textSnippets,
                        "screenshotHash" to snap.screenshotHash,
                    ),
                )
            }
            "clear" -> {
                ContextCaptureEngine.clear()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
