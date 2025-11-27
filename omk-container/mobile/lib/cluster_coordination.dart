import 'mesh_peer.dart';
import 'mesh_leader.dart';
import 'node_identity.dart';

/// Simple description of a shared inference task.
class ClusterTask {
  ClusterTask({
    required this.id,
    required this.kind,
    required this.payload,
  });

  final String id;
  final String kind; // e.g. 'url_risk_batch', 'summary_batch'
  final Map<String, Object?> payload;
}

/// Coordination helper for local inference clusters.
class ClusterCoordinator {
  ClusterCoordinator(this._localIdentity);

  final NodeIdentity _localIdentity;

  MeshPeer? selectCoordinator(List<MeshPeer> peers) {
    return MeshLeaderSelector.chooseLeader(peers, _localIdentity);
  }
}
