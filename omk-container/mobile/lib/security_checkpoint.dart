import 'security_decision_flow.dart';

enum SecurityAlertLevel { safe, warn, alert }

class SecurityCheckpointResult {
  SecurityCheckpointResult({
    required this.score,
    required this.level,
    required this.reasons,
  });

  /// 0–100 risk score.
  final int score;
  final SecurityAlertLevel level;
  final List<String> reasons;
}

/// Real-time Security Checkpoint that combines static and dynamic signals
/// into a single 0–100 score and alert level.
class SecurityCheckpoint {
  static SecurityCheckpointResult evaluate(SecurityDecision decision) {
    final reasons = <String>[];

    // Start from decision.riskScore (0–1) scaled to 0–100.
    var score = (decision.riskScore * 100).clamp(0.0, 100.0) as double;

    // Parse path for additional static signals.
    final path = decision.path;
    final bloomHit = path.any((p) => p.startsWith('bloom_hit'));
    final fuzzyHit = path.any((p) => p.startsWith('fuzzy_hit'));

    if (bloomHit) {
      score += 15; // known-risk domain boost
      reasons.add('Matches known-risk host (Bloom filter)');
    }

    if (fuzzyHit) {
      reasons.add('Similar to previously risky context');
    }

    // Boost if verdict is block or review.
    if (decision.verdict == 'block') {
      score = (score + 20).clamp(0.0, 100.0);
      reasons.add('Local/remote engine marked this as BLOCK');
    } else if (decision.verdict == 'review') {
      score = (score + 10).clamp(0.0, 100.0);
      reasons.add('Needs human review');
    }

    final normalized = score.clamp(0.0, 100.0).round();
    final level = _levelForScore(normalized);

    if (reasons.isEmpty) {
      reasons.add('No strong risk indicators beyond base model score');
    }

    return SecurityCheckpointResult(
      score: normalized,
      level: level,
      reasons: reasons,
    );
  }

  static SecurityAlertLevel _levelForScore(int score) {
    if (score >= 80) return SecurityAlertLevel.alert; // hard alert
    if (score >= 60) return SecurityAlertLevel.warn; // soft warning
    return SecurityAlertLevel.safe;
  }
}
