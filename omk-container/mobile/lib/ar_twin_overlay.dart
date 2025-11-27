import 'twin_identity.dart';
import 'mesh_peer.dart';

/// Logical representation of a twin as shown in AR.
class ARTwinEntity {
  ARTwinEntity({
    required this.twinId,
    required this.nodeId,
    required this.brightness,
    required this.health,
  });

  final String twinId;
  final String nodeId;

  /// 0-1 visual brightness / intensity used by AR layer.
  final double brightness;

  /// 0-1 mesh health for this twin (connectivity, consensus, etc.).
  final double health;
}

/// Helper to build AR twin entities from mesh peers and twin identities.
class ARTwinOverlayPlanner {
  static List<ARTwinEntity> build(
    TwinIdentity local,
    List<MeshPeer> peers,
  ) {
    return peers
        .map(
          (p) => ARTwinEntity(
            twinId: 'unknown', // to be replaced when twin IDs are known.
            nodeId: p.nodeId,
            brightness: 0.7,
            health: 0.5,
          ),
        )
        .toList(growable: false);
  }
}
