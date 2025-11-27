package com.omk.container.vpn

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter plugin skeleton to control OmkVpnService from Dart.
 *
 * Channel: `omk_container/vpn`
 * Methods:
 * - startVpn()
 * - stopVpn()
 * - setDeepAnalysis(bool)
 */
class OmkVpnPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var context: Context? = null
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "omk_container/vpn")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startVpn" -> {
                startVpn()
                result.success(null)
            }
            "stopVpn" -> {
                stopVpn()
                result.success(null)
            }
            "setDeepAnalysis" -> {
                val enabled = (call.argument<Boolean>("enabled") ?: false)
                PacketMetadataCollector.deepAnalysisGlobal = enabled
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startVpn() {
        val ctx = context ?: return
        try {
            val intent = VpnService.prepare(ctx)
            if (intent != null) {
                // In a full implementation, you would surface this intent to the user via Activity.
                Log.w(TAG, "VpnService.prepare returned an intent; user consent UI must be shown in host app.")
                return
            }
            val svcIntent = Intent(ctx, OmkVpnService::class.java).apply {
                action = OmkVpnService.ACTION_START
            }
            ContextCompat.startForegroundService(ctx, svcIntent)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to start VPN", t)
        }
    }

    private fun stopVpn() {
        val ctx = context ?: return
        try {
            val svcIntent = Intent(ctx, OmkVpnService::class.java).apply {
                action = OmkVpnService.ACTION_STOP
            }
            ctx.startService(svcIntent)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to stop VPN", t)
        }
    }

    companion object {
        private const val TAG = "OmkVpnPlugin"
    }
}
