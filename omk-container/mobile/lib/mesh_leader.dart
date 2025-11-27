import 'mesh_peer.dart';
import 'node_identity.dart';

/// Helper for selecting a temporary mesh leader from a set of peers.
class MeshLeaderSelector {
  /// Pick the best candidate leader from the provided peers.
  ///
  /// Current heuristic:
  /// - Prefer nodes advertising role.gateway, then relay, then leaf.
  /// - Within the same role, prefer stronger RSSI.
  /// - Tie-breaker: lexicographically smallest nodeId.
  static MeshPeer? chooseLeader(List<MeshPeer> peers, NodeIdentity local) {
    if (peers.isEmpty) return null;

    int roleRank(NodeRole? role) {
      switch (role) {
        case NodeRole.gateway:
          return 0;
        case NodeRole.relay:
          return 1;
        case NodeRole.leaf:
        case null:
          return 2;
      }
    }

    // Include self as candidate gateway/relay if needed in future; for now we
    // just consider visible peers.
    peers.sort((a, b) {
      final ar = roleRank(a.role);
      final br = roleRank(b.role);
      if (ar != br) return ar - br;
      if (a.rssi != b.rssi) return b.rssi - a.rssi; // stronger first
      return a.nodeId.compareTo(b.nodeId);
    });
    return peers.first;
  }
}
