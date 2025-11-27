import 'connectivity_mode.dart';

/// High-level routing hint used by AutonomyEngine/IntentRouter.
class RoutingHint {
  RoutingHint({
    required this.mode,
    required this.confidence,
  });

  final ConnectivityMode mode;
  final double confidence; // 0-1
}
