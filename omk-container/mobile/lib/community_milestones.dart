/// Gamified community milestones.
class CommunityMilestones {
  CommunityMilestones({
    required this.hiveLevel,
    required this.meshReach,
    required this.uptimeScore,
  });

  /// Overall community level (abstract score).
  final int hiveLevel;

  /// Approximate number of distinct nodes reached over time.
  final int meshReach;

  /// Composite uptime/reliability score (0-100).
  final int uptimeScore;
}
