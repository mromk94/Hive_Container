package com.omk.container.vpn

import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.net.InetSocketAddress
import java.nio.ByteBuffer

/**
 * OMK VPN skeleton
 *
 * - Creates a local VPN tunnel (TUN interface).
 * - Reads packets and forwards metadata to DnsProxy / PacketMetadataCollector.
 * - Intended to run as a foreground service with explicit user consent.
 */
class OmkVpnService : VpnService() {

    private var tunInterface: ParcelFileDescriptor? = null
    private var vpnJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "OmkVpnService created")
    }

    override fun onDestroy() {
        super.onDestroy()
        stopTunnel()
        Log.i(TAG, "OmkVpnService destroyed")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        when (action) {
            ACTION_START -> startTunnel()
            ACTION_STOP -> stopSelf()
        }
        return START_STICKY
    }

    private fun startTunnel() {
        if (tunInterface != null) return

        val builder = Builder()
            .setSession("OMK Container VPN")
            .setMtu(1500)
            // Example TUN address; replace with safe local-only range
            .addAddress("10.0.0.2", 32)
            // Default route; in real use, consider app- or domain-based routing
            .addRoute("0.0.0.0", 0)

        // Example DNS server (localhost) where DnsProxy will listen
        builder.addDnsServer("10.0.0.1")

        // Optionally restrict to specific apps (per-allowlist)
        // builder.addAllowedApplication("com.example.someapp")

        val configureIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, javaClass).setAction("com.omk.container.vpn.CONFIGURE"),
            PendingIntent.FLAG_MUTABLE
        )
        builder.setConfigureIntent(configureIntent)

        tunInterface = builder.establish()
        Log.i(TAG, "OmkVpnService tunnel established")

        vpnJob = CoroutineScope(Dispatchers.IO).launch {
            runPacketLoop()
        }
    }

    private fun stopTunnel() {
        try {
            vpnJob?.cancel()
            vpnJob = null
            tunInterface?.close()
            tunInterface = null
            Log.i(TAG, "OmkVpnService tunnel stopped")
        } catch (t: Throwable) {
            Log.e(TAG, "Error stopping tunnel", t)
        }
    }

    private suspend fun runPacketLoop() {
        val fd = tunInterface?.fileDescriptor ?: return
        val input = ParcelFileDescriptor.AutoCloseInputStream(tunInterface).channel
        val buffer = ByteBuffer.allocateDirect(32767)

        val dnsProxy = DnsProxy()
        val metadataCollector = PacketMetadataCollector()

        while (!Thread.interrupted()) {
            buffer.clear()
            val read = input.read(buffer)
            if (read <= 0) continue
            buffer.flip()

            try {
                val info = metadataCollector.parsePacket(buffer)
                if (info != null) {
                    if (info.isDns) {
                        dnsProxy.handleDnsPacket(info)
                    } else {
                        // For TLS / TCP flows, feed to TLS metadata extractor if applicable
                        TlsMetadataExtractor.maybeInspect(info)
                        metadataCollector.logConnection(info)
                    }
                }
            } catch (t: Throwable) {
                Log.e(TAG, "Error parsing packet", t)
            }
        }
    }

    companion object {
        private const val TAG = "OmkVpnService"
        const val ACTION_START = "com.omk.container.vpn.START"
        const val ACTION_STOP = "com.omk.container.vpn.STOP"
    }
}

/**
 * Example manifest entries (AndroidManifest.xml):
 *
 * <uses-permission android:name="android.permission.INTERNET" />
 * <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
 * <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
 *
 * <application ...>
 *   <service
 *     android:name=".vpn.OmkVpnService"
 *     android:permission="android.permission.BIND_VPN_SERVICE"
 *     android:exported="false">
 *     <intent-filter>
 *       <action android:name="android.net.VpnService" />
 *     </intent-filter>
 *   </service>
 * </application>
 */
