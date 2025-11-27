/// Entry in the cooperative cache shared with nearby OMK nodes.
class CoopCacheEntry {
  CoopCacheEntry({
    required this.urlHash,
    required this.host,
    required this.verdict,
    required this.riskScore,
    required this.ttlMillis,
    required this.originNodeId,
    required this.createdAtMillis,
  });

  final String urlHash;
  final String host;
  final String verdict; // e.g. 'allow' | 'review' | 'block'
  final double riskScore; // 0-1
  final int ttlMillis;
  final String originNodeId;
  final int createdAtMillis;

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch > createdAtMillis + ttlMillis;

  Map<String, Object?> toJson() => <String, Object?>{
        'url_hash': urlHash,
        'host': host,
        'verdict': verdict,
        'risk_score': riskScore,
        'ttl_ms': ttlMillis,
        'origin_node_id': originNodeId,
        'created_at': createdAtMillis,
      };

  static CoopCacheEntry fromJson(Map<String, Object?> json) {
    return CoopCacheEntry(
      urlHash: json['url_hash'] as String,
      host: json['host'] as String,
      verdict: json['verdict'] as String,
      riskScore: (json['risk_score'] as num).toDouble(),
      ttlMillis: json['ttl_ms'] as int,
      originNodeId: json['origin_node_id'] as String,
      createdAtMillis: json['created_at'] as int,
    );
  }
}

/// Simple in-memory cooperative cache; callers are responsible for deciding
/// when to persist or sync entries.
class CoopCache {
  final List<CoopCacheEntry> _entries = <CoopCacheEntry>[];

  void add(CoopCacheEntry entry) {
    _entries.removeWhere((e) => e.urlHash == entry.urlHash);
    _entries.add(entry);
  }

  List<CoopCacheEntry> listActive() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _entries.removeWhere((e) => now > e.createdAtMillis + e.ttlMillis);
    return List<CoopCacheEntry>.unmodifiable(_entries);
  }
}
