package com.example.omk_container_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pDeviceList
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val overlayChannelName = "omk.overlay"
    private lateinit var overlayChannel: MethodChannel
    private val meshChannelName = "omk.mesh.discovery"
    private val meshEventsName = "omk.mesh.discovery.events"
    private lateinit var meshChannel: MethodChannel
    private lateinit var meshEvents: EventChannel
    private var meshEventsSink: EventChannel.EventSink? = null
    private lateinit var meshTransportChannel: MethodChannel
    private val importChannelName = "omk.import"
    private lateinit var importChannel: MethodChannel

    private var wifiP2pManager: WifiP2pManager? = null
    private var wifiChannel: WifiP2pManager.Channel? = null
    private var wifiReceiver: BroadcastReceiver? = null
    private var wifiDiscoveryRunning: Boolean = false
    private var pendingOverlayTap: Boolean = false
    private var pendingImportUrl: String? = null

    private val REQUEST_LOCATION_PERMISSION = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        overlayChannel = MethodChannel(messenger, overlayChannelName)
        overlayChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isOverlayAvailable" -> {
                        result.success(canDrawOverlays())
                    }
                    "openOverlaySettings" -> {
                        openOverlaySettings()
                        result.success(null)
                    }
                    "startOverlay" -> {
                        if (canDrawOverlays()) {
                            OverlayBubbleService.start(this)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "stopOverlay" -> {
                        OverlayBubbleService.stop(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        meshChannel = MethodChannel(messenger, meshChannelName)
        meshChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ensurePermissions" -> {
                    val ok = ensureLocationPermission()
                    result.success(ok)
                }
                "startDiscovery" -> {
                    startWifiP2pDiscovery()
                    result.success(true)
                }
                "stopDiscovery" -> {
                    stopWifiP2pDiscovery()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        importChannel = MethodChannel(messenger, importChannelName)
        importChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingImportUrl" -> {
                    result.success(pendingImportUrl)
                }
                "clearPendingImportUrl" -> {
                    pendingImportUrl = null
                    result.success(null)
                }
                "setClipboardWatcherEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (enabled) {
                        ClipboardWatcherService.start(this)
                    } else {
                        ClipboardWatcherService.stop(this)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        meshEvents = EventChannel(messenger, meshEventsName)
        meshEvents.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                meshEventsSink = events
            }

            override fun onCancel(arguments: Any?) {
                meshEventsSink = null
            }
        })

        meshTransportChannel = MethodChannel(messenger, "omk.mesh.transport")
        meshTransportChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendMeshPayload" -> {
                    val payload = call.argument<Map<String, Any?>>("payload")
                    // For now, just log that we would send this over Wi-Fi
                    // Direct once a data channel is established.
                    // In a future slice, this will open a socket to the group
                    // owner or peers.
                    android.util.Log.d(
                        "omk.mesh.transport",
                        "sendMeshPayload: ${payload?.keys?.joinToString()}",
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        if (pendingOverlayTap) {
            notifyOverlayTapped()
            pendingOverlayTap = false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleOverlayIntent(intent)
        handleImportIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        // App is foreground: rely on Flutter bubble, hide native overlay dot.
        OverlayBubbleService.stop(this)
    }

    override fun onPause() {
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleOverlayIntent(intent)
        handleImportIntent(intent)
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun handleOverlayIntent(intent: Intent?) {
        val fromOverlay = intent?.getBooleanExtra("omk.from_overlay", false) ?: false
        if (fromOverlay) {
            if (this::overlayChannel.isInitialized) {
                notifyOverlayTapped()
            } else {
                pendingOverlayTap = true
            }
        }
    }

    private fun handleImportIntent(intent: Intent?) {
        if (intent == null) return
        var url: String? = null
        if (Intent.ACTION_SEND == intent.action && intent.type?.startsWith("text/") == true) {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!sharedText.isNullOrBlank()) {
                url = sharedText.trim()
            }
        }
        val extraUrl = intent.getStringExtra("omk.import_url")
        if (!extraUrl.isNullOrBlank()) {
            url = extraUrl.trim()
        }
        if (!url.isNullOrBlank()) {
            pendingImportUrl = url
            if (this::importChannel.isInitialized) {
                importChannel.invokeMethod("incomingUrl", url)
            }
        }
    }

    private fun notifyOverlayTapped() {
        overlayChannel.invokeMethod("overlayTapped", null)
    }

    private fun ensureWifiP2p() {
        if (wifiP2pManager != null && wifiChannel != null) return
        val mgr = getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
        wifiP2pManager = mgr
        if (mgr != null) {
            wifiChannel = mgr.initialize(this, mainLooper, null)
        }
    }

    private fun startWifiP2pDiscovery() {
        ensureWifiP2p()
        val mgr = wifiP2pManager ?: return
        val ch = wifiChannel ?: return
        if (wifiDiscoveryRunning) return

        val filter = IntentFilter().apply {
            addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
        }
        wifiReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null) return
                if (WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION == intent.action) {
                    mgr.requestPeers(ch) { peers: WifiP2pDeviceList? ->
                        val devices = peers?.deviceList ?: emptySet<WifiP2pDevice>()
                        val now = System.currentTimeMillis()
                        val list = devices.map { d ->
                            mapOf(
                                "nodeId" to (d.deviceAddress ?: "unknown"),
                                "rssi" to -60,
                                "lastSeenMillis" to now,
                            )
                        }
                        meshEventsSink?.success(list)
                    }
                }
            }
        }
        registerReceiver(wifiReceiver, filter)

        mgr.discoverPeers(ch, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                wifiDiscoveryRunning = true
            }

            override fun onFailure(reason: Int) {
                // Leave running=false; discovery not started.
            }
        })
    }

    private fun stopWifiP2pDiscovery() {
        val mgr = wifiP2pManager
        val ch = wifiChannel
        if (mgr == null || ch == null) return
        if (!wifiDiscoveryRunning) return
        wifiDiscoveryRunning = false
        try {
            mgr.stopPeerDiscovery(ch, null)
        } catch (_: Exception) {
        }
        try {
            if (wifiReceiver != null) {
                unregisterReceiver(wifiReceiver)
                wifiReceiver = null
            }
        } catch (_: Exception) {
        }
    }

    private fun hasLocationPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun ensureLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        if (hasLocationPermission()) return true
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
            REQUEST_LOCATION_PERMISSION,
        )
        return false
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_LOCATION_PERMISSION) {
            // If permission is granted and discovery was requested, it will
            // succeed on the next startWifiP2pDiscovery() call.
        }
    }
}
