/// Statistics about mesh topology used for self-evolving behaviors.
class TopologyStats {
  TopologyStats({
    required this.observedLinks,
    required this.avgLatencyMs,
  });

  final int observedLinks;
  final int avgLatencyMs;
}
