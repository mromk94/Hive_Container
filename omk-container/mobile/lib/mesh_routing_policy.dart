import 'mesh_peer.dart';
import 'node_quarantine.dart';

/// Mesh routing policy that filters out banned nodes before use.
class MeshRoutingPolicy {
  /// Returns the subset of peers that are not explicitly banned by the
  /// local NodeQuarantineManager.
  static Future<List<MeshPeer>> filterAllowedPeers(List<MeshPeer> peers) async {
    final result = <MeshPeer>[];
    for (final p in peers) {
      if (await NodeQuarantineManager.isBanned(p.nodeId)) {
        continue;
      }
      result.add(p);
    }
    return result;
  }
}
