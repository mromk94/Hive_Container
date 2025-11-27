import 'signal_telemetry.dart';

/// Simple in-process telemetry helper for network calls.
class NetworkTelemetry {
  NetworkTelemetry._();

  static final NetworkTelemetry instance = NetworkTelemetry._();

  SignalTelemetry _current = const SignalTelemetry(
    netReachable: true,
    avgLatencyMs: 200,
    llmFailureRate: 0.0,
    lastModeChangeMillis: 0,
  );

  SignalTelemetry get current => _current;

  final List<void Function(SignalTelemetry)> _listeners = [];

  void addListener(void Function(SignalTelemetry) listener) {
    _listeners.add(listener);
    // Immediately inform new listeners of the current snapshot.
    listener(_current);
  }

  void removeListener(void Function(SignalTelemetry) listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    // Work on a copy in case listeners mutate the list.
    for (final l in List<void Function(SignalTelemetry)>.from(_listeners)) {
      l(_current);
    }
  }

  /// Update telemetry based on a single network call.
  void recordCall({required bool success, required int latencyMs}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final failureDelta = success ? -0.05 : 0.1;
    final newFailureRate = (_current.llmFailureRate + failureDelta)
        .clamp(0.0, 1.0);
    final newLatency = ((_current.avgLatencyMs * 3) + latencyMs) ~/ 4;
    _current = _current.copyWith(
      netReachable: success || _current.netReachable,
      avgLatencyMs: newLatency,
      llmFailureRate: newFailureRate,
      lastModeChangeMillis: now,
    );
    _notifyListeners();
  }
}
