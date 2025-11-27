import 'dart:async';

import 'package:flutter/services.dart';

import 'mesh_discovery.dart';
import 'mesh_peer.dart';
import 'node_identity.dart';

class AndroidMeshDiscoveryService implements MeshDiscoveryService {
  AndroidMeshDiscoveryService();

  static const MethodChannel _channel = MethodChannel('omk.mesh.discovery');
  static const EventChannel _events = EventChannel('omk.mesh.discovery.events');

  final StreamController<List<MeshPeer>> _controller =
      StreamController<List<MeshPeer>>.broadcast();

  StreamSubscription<dynamic>? _sub;
  bool _started = false;

  @override
  Stream<List<MeshPeer>> get peersStream => _controller.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Ask Android to ensure location permission; on first run this will
    // trigger a runtime dialog on supported versions.
    try {
      await _channel.invokeMethod('ensurePermissions');
    } catch (_) {}

    _sub = _events.receiveBroadcastStream().listen(
      (dynamic data) async {
        final list = (data as List<dynamic>?) ?? const [];
        final now = DateTime.now().millisecondsSinceEpoch;
        final self = await NodeIdentity.load();
        final peers = <MeshPeer>[];
        for (final item in list) {
          if (item is! Map) continue;
          final nodeId = (item['nodeId'] as String?) ?? 'unknown';
          if (nodeId == self.nodeId) continue;
          final rssi = (item['rssi'] as int?) ?? -60;
          final lastSeen = (item['lastSeenMillis'] as int?) ?? now;
          peers.add(
            MeshPeer(
              nodeId: nodeId,
              transport: MeshTransportType.wifiDirect,
              rssi: rssi,
              lastSeenMillis: lastSeen,
              role: null,
            ),
          );
        }
        _controller.add(peers);
      },
      onError: (Object error, StackTrace stack) {
        // Keep errors local to the stream; just drop peers on error.
      },
    );

    await _channel.invokeMethod('startDiscovery');
  }

  @override
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    try {
      await _channel.invokeMethod('stopDiscovery');
    } catch (_) {
      // ignore
    }
    await _sub?.cancel();
    _sub = null;
  }
}
