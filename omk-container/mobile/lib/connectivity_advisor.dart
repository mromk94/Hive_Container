import 'connectivity_mode.dart';
import 'network_telemetry.dart';

/// Helper that maps current network telemetry into a coarse
/// ConnectivityMode. This does not update any providers by itself; call
/// it where you need a quick routing decision.
class ConnectivityAdvisor {
  ConnectivityAdvisor._();

  static ConnectivityMode currentMode() {
    final t = NetworkTelemetry.instance.current;
    if (!t.netReachable || t.llmFailureRate > 0.6) {
      return ConnectivityMode.offline;
    }
    // Placeholder: when local mesh is wired we can use additional
    // telemetry to select ConnectivityMode.localMesh here.
    return ConnectivityMode.cloud;
  }
}
