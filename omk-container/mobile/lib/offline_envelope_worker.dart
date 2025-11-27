import 'dart:developer' as dev;

import 'package:dio/dio.dart';

import 'mesh_ledger_store.dart';
import 'network_telemetry.dart';
import 'offline_envelope_store.dart';

/// Minimal worker that drains a small number of offline envelopes and
/// forwards security tickets to Hive Bridge. Other envelope types are
/// currently logged only.
class OfflineEnvelopeWorker {
  static Future<void> runOnce({int maxCount = 10}) async {
    final batch = await OfflineEnvelopeStore.drainUpTo(maxCount);
    if (batch.isEmpty) return;

    final dio = Dio();

    for (final env in batch) {
      switch (env.type) {
        case 'security_ticket':
          await _forwardSecurityTicket(dio, env);
          break;
        case 'mesh_event':
          await _forwardMeshEvent(dio, env);
          break;
        default:
          dev.log(
            'Offline envelope drained',
            name: 'omk.offline',
            error: env.payload,
          );
      }
    }
  }

  static Future<void> _forwardSecurityTicket(
    Dio dio,
    OfflineEnvelope env,
  ) async {
    final startMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final payload = <String, Object?>{
        'incidentId': (env.payload['id'] as String?) ?? env.id,
        'context': <String, Object?>{
          'local_ticket': env.payload,
        },
      };

      final res = await dio.post(
        'http://10.0.2.2:4317/escalate',
        data: payload,
      );
      final data = res.data;
      dev.log(
        'Security ticket escalated',
        name: 'omk.offline',
        error: data,
      );

      final dt = DateTime.now().millisecondsSinceEpoch - startMs;
      NetworkTelemetry.instance.recordCall(success: true, latencyMs: dt);
      await MeshLedgerStore.append(
        'security_ticket_forward',
        <String, Object?>{
          'env_id': env.id,
          'created_at': env.createdAtMillis,
        },
      );
    } catch (e, st) {
      final dt = DateTime.now().millisecondsSinceEpoch - startMs;
      NetworkTelemetry.instance.recordCall(success: false, latencyMs: dt);
      dev.log(
        'Failed to escalate security ticket',
        name: 'omk.offline',
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<void> _forwardMeshEvent(
    Dio dio,
    OfflineEnvelope env,
  ) async {
    final startMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final res = await dio.post(
        'http://10.0.2.2:4317/mesh-event',
        data: env.payload,
      );
      final data = res.data;
      dev.log(
        'Mesh event forwarded',
        name: 'omk.offline',
        error: data,
      );

      final dt = DateTime.now().millisecondsSinceEpoch - startMs;
      NetworkTelemetry.instance.recordCall(success: true, latencyMs: dt);
      await MeshLedgerStore.append(
        'mesh_event_forward',
        <String, Object?>{
          'env_id': env.id,
          'created_at': env.createdAtMillis,
        },
      );
    } catch (e, st) {
      final dt = DateTime.now().millisecondsSinceEpoch - startMs;
      NetworkTelemetry.instance.recordCall(success: false, latencyMs: dt);
      dev.log(
        'Failed to forward mesh event',
        name: 'omk.offline',
        error: e,
        stackTrace: st,
      );
    }
  }
}
