/// Simple representation of overall mesh health for visualization.
class MeshHealthStatus {
  const MeshHealthStatus({
    required this.nodeCount,
    required this.avgSignal,
    required this.alertLevel,
  });

  final int nodeCount;
  final double avgSignal; // normalized 0-1
  final double alertLevel; // 0-1, where 1 is high risk.
}
