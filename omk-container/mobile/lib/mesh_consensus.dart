/// Single vote from a mesh node for a key/value pair (e.g., url_hash → malicious).
class MeshVote {
  MeshVote({
    required this.key,
    required this.value,
    required this.weight,
    required this.originNodeId,
    required this.createdAtMillis,
  });

  final String key;
  final String value;
  final double weight;
  final String originNodeId;
  final int createdAtMillis;
}

class MeshConsensusResult {
  MeshConsensusResult({
    required this.key,
    required this.value,
    required this.support,
    required this.totalWeight,
  });

  final String key;
  final String value;
  final double support; // 0-1
  final double totalWeight;
}

/// Lightweight quorum-based consensus helper.
class MeshConsensus {
  /// Fold votes into a single decision if support >= minSupport.
  static MeshConsensusResult? decide(
    String key,
    Iterable<MeshVote> votes, {
    double minSupport = 0.6,
  }) {
    final candidates = <String, double>{};
    double total = 0;
    for (final v in votes) {
      if (v.key != key) continue;
      total += v.weight;
      candidates[v.value] = (candidates[v.value] ?? 0) + v.weight;
    }
    if (total == 0) return null;
    String? bestValue;
    double bestWeight = 0;
    candidates.forEach((value, w) {
      if (w > bestWeight) {
        bestWeight = w;
        bestValue = value;
      }
    });
    if (bestValue == null) return null;
    final support = bestWeight / total;
    if (support < minSupport) return null;
    return MeshConsensusResult(
      key: key,
      value: bestValue!,
      support: support,
      totalWeight: total,
    );
  }
}
