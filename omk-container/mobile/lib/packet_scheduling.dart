import 'signal_telemetry.dart';

/// Priority levels for mesh packets when signal is weak.
enum PacketPriority { high, medium, low }

class PacketSchedulingDecision {
  PacketSchedulingDecision({
    required this.priority,
    required this.compress,
  });

  final PacketPriority priority;
  final bool compress;
}

/// Simple helper that decides how aggressively to compress and which
/// priority to assign based on current signal telemetry.
class PacketScheduler {
  static PacketSchedulingDecision decide(SignalTelemetry t) {
    if (!t.netReachable || t.avgLatencyMs > 2000 || t.llmFailureRate > 0.5) {
      return PacketSchedulingDecision(
        priority: PacketPriority.high,
        compress: true,
      );
    }
    if (t.avgLatencyMs > 800) {
      return PacketSchedulingDecision(
        priority: PacketPriority.medium,
        compress: true,
      );
    }
    return PacketSchedulingDecision(
      priority: PacketPriority.low,
      compress: false,
    );
  }
}
