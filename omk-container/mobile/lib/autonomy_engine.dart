import 'package:shared_preferences/shared_preferences.dart';

import 'intent_router.dart';

/// Simple autonomy engine that maintains per-intent routing weights
/// and allows reinforcement based on user feedback.
class AutonomyEngine {
  AutonomyEngine._();

  static const _keyPrefix = 'autonomy_weight_';
  static final Map<IntentType, double> _weights = {
    IntentType.security: 1.0,
    IntentType.summarization: 1.0,
    IntentType.recommendation: 1.0,
  };

  static bool _loaded = false;

  /// Load weights from persistent storage. Safe to call multiple times.
  static Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    for (final type in IntentType.values) {
      final key = '$_keyPrefix${type.name}';
      final v = prefs.getDouble(key);
      if (v != null && v > 0) {
        _weights[type] = v;
      }
    }
    _loaded = true;
  }

  /// Read the current weight for an intent type (defaults to 1.0).
  static double weightFor(IntentType type) {
    return _weights[type] ?? 1.0;
  }

  /// Apply a simple reinforcement update:
  /// - positive feedback: weight *= 1.05 (capped at 2.0)
  /// - negative feedback: weight *= 0.95 (floored at 0.3)
  static Future<void> recordFeedback(IntentType type, {required bool positive}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _weights[type] ?? 1.0;
    final updated = positive
        ? (current * 1.05).clamp(0.3, 2.0)
        : (current * 0.95).clamp(0.3, 2.0);
    _weights[type] = updated;
    final key = '$_keyPrefix${type.name}';
    await prefs.setDouble(key, updated);
  }
}
