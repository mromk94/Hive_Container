import 'package:uuid/uuid.dart';

import 'network_telemetry.dart';
import 'signal_telemetry.dart';
import 'time_synced_snapshot.dart';

/// Builds L-Mesh context packets following L-MESH-CONTEXT-PROTOCOL.md.
class MeshPacketBuilder {
  MeshPacketBuilder._();

  static const _uuid = Uuid();

  static Map<String, Object?> build({
    required TimeSyncedSnapshot snapshot,
    String? packetId,
    int ttlMs = 30000,
  }) {
    final id = packetId ?? _uuid.v4();
    final SignalTelemetry t = NetworkTelemetry.instance.current;

    return <String, Object?>{
      'packet_id': id,
      'origin_node_id': snapshot.packet.toJson()['host'] ?? 'unknown',
      'created_at': snapshot.createdAtMillis,
      'ttl_ms': ttlMs,
      'hop_count': 0,
      'visibility': 'local_only',
      'snapshot': snapshot.packet.toJson(),
      'local_signals': <String, Object?>{
        'bloom_hit': false,
        'local_risk_score': null,
        'checkpoint_score': null,
        'checkpoint_level': null,
        'net_reachable': t.netReachable,
        'avg_latency_ms': t.avgLatencyMs,
        'llm_failure_rate': t.llmFailureRate,
      },
    };
  }
}
