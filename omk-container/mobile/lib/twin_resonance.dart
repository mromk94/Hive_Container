/// Pairwise resonance metrics between this twin and a peer twin.
///
/// These values are soft signals used to capture how aligned two twins are
/// in tone, knowledge, and situational awareness. Higher values are closer
/// to 1.0.
class TwinResonanceMetric {
  TwinResonanceMetric({
    required this.peerTwinId,
    required this.toneAlignment,
    required this.knowledgeOverlap,
    required this.awarenessSync,
    required this.updatedAtMillis,
  });

  final String peerTwinId;
  final double toneAlignment; // 0-1
  final double knowledgeOverlap; // 0-1
  final double awarenessSync; // 0-1
  final int updatedAtMillis;

  Map<String, Object?> toJson() => <String, Object?>{
        'peer_twin_id': peerTwinId,
        'tone_alignment': toneAlignment,
        'knowledge_overlap': knowledgeOverlap,
        'awareness_sync': awarenessSync,
        'updated_at': updatedAtMillis,
      };

  static TwinResonanceMetric fromJson(Map<String, Object?> json) {
    return TwinResonanceMetric(
      peerTwinId: json['peer_twin_id'] as String,
      toneAlignment: (json['tone_alignment'] as num).toDouble(),
      knowledgeOverlap: (json['knowledge_overlap'] as num).toDouble(),
      awarenessSync: (json['awareness_sync'] as num).toDouble(),
      updatedAtMillis: json['updated_at'] as int,
    );
  }

  /// Merge local and remote views of resonance, preferring newer data but
  /// smoothing via averaging.
  static TwinResonanceMetric merge(
    TwinResonanceMetric a,
    TwinResonanceMetric b,
  ) {
    final newer = a.updatedAtMillis >= b.updatedAtMillis ? a : b;
    final older = identical(newer, a) ? b : a;
    double mix(double x, double y) => ((x + y) / 2).clamp(0.0, 1.0);
    return TwinResonanceMetric(
      peerTwinId: newer.peerTwinId,
      toneAlignment: mix(newer.toneAlignment, older.toneAlignment),
      knowledgeOverlap: mix(newer.knowledgeOverlap, older.knowledgeOverlap),
      awarenessSync: mix(newer.awarenessSync, older.awarenessSync),
      updatedAtMillis: newer.updatedAtMillis,
    );
  }
}
