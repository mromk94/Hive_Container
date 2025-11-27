package com.omk.container.vpn

import android.util.Log
import java.security.MessageDigest
import java.security.cert.Certificate
import java.security.cert.X509Certificate
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLSession

/**
 * TLS metadata extractor (no MITM).
 *
 * Inspects SSLSession / X509Certificate and logs:
 * - certificate fingerprints (SHA-256)
 * - issuer and subject
 * - validity (notBefore/notAfter)
 * - SNI/hostname when available
 */
object TlsMetadataExtractor {

    private const val TAG = "OmkTlsMeta"

    fun maybeInspect(info: PacketInfo) {
        // This hook is intended for future mapping between PacketInfo and live connections.
        // For now this is a no-op skeleton.
    }

    fun logFromConnection(conn: HttpsURLConnection) {
        try {
            val session: SSLSession = conn.session
            val peer = session.peerCertificates.firstOrNull() as? X509Certificate ?: return
            logCert(peer, session.peerHost)
        } catch (t: Throwable) {
            Log.e(TAG, "TLS metadata error", t)
        }
    }

    fun logCert(cert: X509Certificate, host: String?) {
        val fp = fingerprint(cert)
        Log.d(
            TAG,
            "TLS cert host=${host ?: "-"} sha256=$fp issuer=${cert.issuerX500Principal.name} " +
                "subject=${cert.subjectX500Principal.name} notBefore=${cert.notBefore} notAfter=${cert.notAfter}",
        )
        SecurityEventLogger.logTlsCert(
            host = host,
            sha256 = fp,
            issuer = cert.issuerX500Principal.name,
            subject = cert.subjectX500Principal.name,
        )
    }

    private fun fingerprint(cert: Certificate): String {
        val md = MessageDigest.getInstance("SHA-256")
        val bytes = md.digest(cert.encoded)
        return bytes.joinToString(":") { b -> "%02X".format(b) }
    }
}

/**
 * Simple test harness for TLS metadata extraction.
 *
 * This is intended to be run as a JVM test (not on device) to verify parsing.
 */
object TlsMetadataTestHarness {
    @JvmStatic
    fun main(args: Array<String>) {
        val url = java.net.URL("https://example.com")
        val conn = (url.openConnection() as HttpsURLConnection).apply {
            connectTimeout = 5000
            readTimeout = 5000
        }
        conn.connect()
        TlsMetadataExtractor.logFromConnection(conn)
        conn.disconnect()
    }
}
