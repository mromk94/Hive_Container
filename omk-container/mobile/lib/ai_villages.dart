/// Visualization descriptor for "AI Villages" — clusters of active users.
class AiVillageCluster {
  AiVillageCluster({
    required this.id,
    required this.regionId,
    required this.nodeCount,
    required this.activeTwinCount,
  });

  final String id;
  final String regionId;
  final int nodeCount;
  final int activeTwinCount;
}
