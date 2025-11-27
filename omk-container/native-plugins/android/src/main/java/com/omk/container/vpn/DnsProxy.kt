package com.omk.container.vpn

import android.util.Log
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress

/**
 * Very small DNS proxy skeleton.
 *
 * - Listens on a local UDP socket.
 * - Forwards DNS queries to the system/default resolver.
 * - Logs query/response metadata into a security log (to be bridged to Flutter/SQLite).
 *
 * This is intentionally simplified and does not implement full DNS parsing.
 */
class DnsProxy {

    private val logTag = "OmkDnsProxy"

    // Example system DNS target; in real use discover via LinkProperties
    private val upstreamDns: InetAddress = InetAddress.getByName("8.8.8.8")
    private val upstreamPort: Int = 53

    fun handleDnsPacket(info: PacketInfo) {
        try {
            // info.rawData is the UDP payload; we can parse qname minimally if needed.
            val questionName = safeExtractQname(info.rawData)
            Log.d(logTag, "DNS query: host=$questionName from=${info.sourceIp}")
            SecurityEventLogger.logDnsQuery(questionName, info.sourceIp, info.rawData.size)

            // Forward to upstream
            val socket = DatagramSocket()
            socket.soTimeout = 2000
            val outPacket = DatagramPacket(info.rawData, info.rawData.size, upstreamDns, upstreamPort)
            socket.send(outPacket)

            val buffer = ByteArray(1500)
            val inPacket = DatagramPacket(buffer, buffer.size)
            socket.receive(inPacket)

            // Log response metadata (no payload persisted)
            Log.d(logTag, "DNS response: bytes=${inPacket.length} for $questionName")
            SecurityEventLogger.logDnsQuery(questionName, info.sourceIp, inPacket.length)
            socket.close()

            // TODO: write metadata into OMK security DB via bridging layer
        } catch (t: Throwable) {
            Log.e(logTag, "DNS proxy error", t)
        }
    }

    private fun safeExtractQname(raw: ByteArray): String {
        // Minimal placeholder; real DNS parsing will decode question section.
        return "unknown.example" // TODO: implement real parser
    }
}
