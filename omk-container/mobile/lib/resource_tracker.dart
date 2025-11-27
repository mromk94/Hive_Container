/// Resource distribution snapshot (power, battery, compute credits).
class ResourceSnapshot {
  ResourceSnapshot({
    required this.twinId,
    required this.batteryLevel,
    required this.computeCredits,
    required this.updatedAtMillis,
  });

  final String twinId;
  final int batteryLevel; // 0-100
  final int computeCredits; // abstract units
  final int updatedAtMillis;
}
