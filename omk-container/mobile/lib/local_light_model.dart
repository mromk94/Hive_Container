import 'privacy_sanitizer.dart';
import 'url_risk_model.dart';

/// Abstraction for a tiny on-device "light node" model used when
/// connectivity is poor or cloud is unavailable.
abstract class LocalLightModel {
  Future<double?> riskScore(UrlRiskFeatures features);

  /// Produce a very short, sanitized summary of the given context.
  Future<String> summarizeShort(String rawText);
}

class HeuristicLightModel implements LocalLightModel {
  HeuristicLightModel(this._urlModel);

  final UrlRiskModel _urlModel;

  @override
  Future<double?> riskScore(UrlRiskFeatures features) {
    return _urlModel.predict(features);
  }

  @override
  Future<String> summarizeShort(String rawText) async {
    final sanitized = PrivacySanitizer.sanitize(rawText);
    final trimmed = sanitized.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= 160) return trimmed;
    return '${trimmed.substring(0, 157)}...';
  }
}
