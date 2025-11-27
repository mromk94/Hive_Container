package com.omk.container.vpn

import android.util.Log
import org.json.JSONObject

/**
 * Central hook for security events.
 *
 * For now this only logs JSON to logcat. Later it will:
 * - write into a local SQLite security DB, and/or
 * - forward high-level events to Flutter for Vault sync.
 */
object SecurityEventLogger {

    private const val TAG = "OmkSecurity"

    fun logDnsQuery(host: String, sourceIp: String, bytes: Int) {
        val json = JSONObject()
            .put("type", "dns_query")
            .put("host", host)
            .put("sourceIp", sourceIp)
            .put("bytes", bytes)
        Log.d(TAG, json.toString())
    }

    fun logConnection(info: PacketInfo, payloadBytes: Int) {
        val json = JSONObject()
            .put("type", "connection")
            .put("src", "${info.sourceIp}:${info.sourcePort}")
            .put("dst", "${info.destIp}:${info.destPort}")
            .put("protocol", info.protocol)
            .put("sni", info.sni ?: JSONObject.NULL)
            .put("payloadBytes", payloadBytes)
        Log.d(TAG, json.toString())
    }

    fun logTlsCert(host: String?, sha256: String, issuer: String, subject: String) {
        val json = JSONObject()
            .put("type", "tls_cert")
            .put("host", host ?: JSONObject.NULL)
            .put("sha256", sha256)
            .put("issuer", issuer)
            .put("subject", subject)
        Log.d(TAG, json.toString())
    }
}
