package com.omk.container.vpn

import android.util.Log
import java.nio.ByteBuffer

/**
 * Packet metadata representation.
 *
 * This deliberately excludes payload unless deepAnalysisEnabled is true.
 */
data class PacketInfo(
    val sourceIp: String,
    val sourcePort: Int,
    val destIp: String,
    val destPort: Int,
    val protocol: String,
    val isDns: Boolean,
    val isTcp: Boolean,
    val sni: String?,
    val rawData: ByteArray,
)

class PacketMetadataCollector {
 
    companion object {
        @JvmStatic
        @Volatile
        var deepAnalysisGlobal: Boolean = false
    }

    var deepAnalysisEnabled: Boolean
        get() = deepAnalysisGlobal
        set(value) {
            deepAnalysisGlobal = value
        }

    fun parsePacket(buffer: ByteBuffer): PacketInfo? {
        // Minimal IPv4 + TCP/UDP parser; IPv6 and other protocols are ignored for now.
        if (buffer.remaining() < 20) return null
        buffer.mark()

        val first = buffer.get().toInt() and 0xFF
        val version = first ushr 4
        if (version != 4) {
            buffer.reset()
            return null
        }
        val ihl = first and 0x0F
        val headerLen = ihl * 4
        if (headerLen < 20 || buffer.remaining() + 1 < headerLen - 1) {
            buffer.reset()
            return null
        }

        // Skip fields we do not currently use
        buffer.get() // TOS
        val totalLen = buffer.short.toInt() and 0xFFFF
        buffer.short // identification
        buffer.short // flags/fragment offset
        buffer.get() // TTL
        val protoByte = buffer.get().toInt() and 0xFF
        buffer.short // header checksum

        val srcBytes = ByteArray(4)
        buffer.get(srcBytes)
        val dstBytes = ByteArray(4)
        buffer.get(dstBytes)

        val srcIp = srcBytes.joinToString(".") { (it.toInt() and 0xFF).toString() }
        val destIp = dstBytes.joinToString(".") { (it.toInt() and 0xFF).toString() }

        // Move to start of transport header
        val payloadOffset = headerLen
        buffer.reset()
        if (buffer.remaining() < payloadOffset + 4) return null
        buffer.position(payloadOffset)

        var srcPort = 0
        var destPort = 0
        var isTcp = false
        var isDns = false

        if (protoByte == 6 || protoByte == 17) { // TCP or UDP
            srcPort = buffer.short.toInt() and 0xFFFF
            destPort = buffer.short.toInt() and 0xFFFF
            isTcp = protoByte == 6
            isDns = !isTcp && (srcPort == 53 || destPort == 53)
        }

        val protocol = when (protoByte) {
            6 -> "TCP"
            17 -> "UDP"
            else -> protoByte.toString()
        }

        // Copy raw bytes up to totalLen (or remaining, whichever is smaller)
        buffer.reset()
        val toCopy = if (totalLen in 1..buffer.remaining()) totalLen else buffer.remaining()
        val raw = ByteArray(toCopy)
        buffer.get(raw, 0, toCopy)

        return PacketInfo(
            sourceIp = srcIp,
            sourcePort = srcPort,
            destIp = destIp,
            destPort = destPort,
            protocol = protocol,
            isDns = isDns,
            isTcp = isTcp,
            sni = null,
            rawData = raw,
        )
    }

    fun logConnection(info: PacketInfo) {
        // Enforce privacy policy: do not log payload unless deep analysis explicitly enabled.
        val payloadBytes = if (deepAnalysisEnabled) info.rawData.size else 0
        Log.d(
            "OmkPacketMeta",
            "conn ${info.sourceIp}:${info.sourcePort} -> ${info.destIp}:${info.destPort} " +
                "proto=${info.protocol} sni=${info.sni ?: "-"} payloadBytes=$payloadBytes",
        )
        SecurityEventLogger.logConnection(info, payloadBytes)
    }
}
