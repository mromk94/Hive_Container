import 'node_identity.dart';

/// Transport used to reach a mesh peer.
enum MeshTransportType { wifiDirect, ble }

/// Lightweight description of a nearby OMK Container node discovered via
/// WiFi Direct or Bluetooth LE.
class MeshPeer {
  MeshPeer({
    required this.nodeId,
    required this.transport,
    required this.rssi,
    required this.lastSeenMillis,
    this.role,
  });

  final String nodeId;
  final MeshTransportType transport;

  /// Received signal strength indicator (dBm) when last observed.
  final int rssi;

  /// Unix timestamp in milliseconds when this peer was last seen.
  final int lastSeenMillis;

  /// Optional advertised role for this node (leaf/relay/gateway).
  final NodeRole? role;
}
