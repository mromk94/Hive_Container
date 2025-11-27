class SignalTelemetry {
  const SignalTelemetry({
    required this.netReachable,
    required this.avgLatencyMs,
    required this.llmFailureRate,
    required this.lastModeChangeMillis,
  });

  final bool netReachable;
  final int avgLatencyMs;
  final double llmFailureRate;
  final int lastModeChangeMillis;

  SignalTelemetry copyWith({
    bool? netReachable,
    int? avgLatencyMs,
    double? llmFailureRate,
    int? lastModeChangeMillis,
  }) {
    return SignalTelemetry(
      netReachable: netReachable ?? this.netReachable,
      avgLatencyMs: avgLatencyMs ?? this.avgLatencyMs,
      llmFailureRate: llmFailureRate ?? this.llmFailureRate,
      lastModeChangeMillis:
          lastModeChangeMillis ?? this.lastModeChangeMillis,
    );
  }
}
