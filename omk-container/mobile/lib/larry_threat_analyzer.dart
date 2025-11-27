import 'local_light_model.dart';
import 'url_risk_model.dart';

/// Larry-State Threat Analysis entrypoint for offline/local mode.
///
/// In this phase it delegates to the LocalLightModel/UrlRiskModel and
/// simple heuristics. In future phases it can incorporate additional
/// signals and models.
class LarryThreatAnalyzer {
  LarryThreatAnalyzer(this._lightModel, this._urlModel);

  final LocalLightModel _lightModel;
  final UrlRiskModel _urlModel;

  Future<double?> offlineUrlRisk(UrlRiskFeatures features) {
    // Delegate to local light model when possible.
    return _lightModel.riskScore(features);
  }
}
