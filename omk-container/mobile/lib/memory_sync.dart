import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'network_telemetry.dart';
import 'packet_scheduling.dart';
import 'security_memory_db.dart';
import 'twin_sync_client.dart';
import 'coop_cache.dart';
import 'mesh_ledger_store.dart';
import 'mesh_persistence.dart';
import 'node_identity.dart';
import 'sync_policy.dart';

/// Client responsible for pushing processed context and decisions to Hive Bridge.
class MemorySyncClient {
  static const _prefsKeyLastSync = 'memory_sync_last_ts';
  static const SyncPolicyConfig policy = SyncPolicyConfig(
    minIntervalMillis: 30 * 1000, // 30s debounce
    maxIntervalMillis: 5 * 60 * 1000, // soft upper bound for future tuning
  );

  static DateTime? _lastSyncStarted;

  /// Trigger a background sync of new security_memory entries.
  ///
  /// This is safe to call opportunistically; it will rate-limit itself.
  static Future<void> syncPending(Dio dio) async {
    final now = DateTime.now();
    if (_lastSyncStarted != null) {
      final elapsed =
          now.millisecondsSinceEpoch - _lastSyncStarted!.millisecondsSinceEpoch;
      if (elapsed < policy.minIntervalMillis) {
        return; // too soon, skip per sync policy
      }
    }
    _lastSyncStarted = now;

    final prefs = await SharedPreferences.getInstance();
    final lastTs = prefs.getInt(_prefsKeyLastSync) ?? 0;

    final db = await SecurityMemoryDb.open();
    final recent = await db.listRecent(limit: 200);
    final toSync = recent
        .where((e) => e.createdAtMillis > lastTs)
        .toList(growable: false);
    if (toSync.isEmpty) return;

    final entries = toSync
        .map((e) => <String, Object?>{
              'url_hash': e.urlHash,
              'host': e.host,
              'verdict': e.verdict,
              'risk_score': e.riskScore,
              'source': e.source,
              'created_at': e.createdAtMillis,
              'fingerprint': _decodeOrNull(e.fingerprintJson),
              'snapshot': _decodeOrNull(e.snapshotJson),
            })
        .toList();

    final sched = PacketScheduler.decide(NetworkTelemetry.instance.current);

    final payload = <String, Object?>{
      'since': lastTs,
      'entries': entries,
      // Placeholder for future encryption flag. When true, `entries` would be
      // encrypted on-device using tenant public key as per BACKEND-PRIVACY-AUTH.
      'encrypted': false,
      'priority': sched.priority.name,
      'compressed': sched.compress,
      'policy': <String, Object?>{
        'min_interval_ms': policy.minIntervalMillis,
        'max_interval_ms': policy.maxIntervalMillis,
      },
    };

    final startMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final res = await dio.post('http://10.0.2.2:4317/memory-sync', data: payload);
      final data = res.data as Map<String, dynamic>?;
      if (data == null || data['ok'] != true) return;
      final newLast = data['lastSynced'] as int? ?? now.millisecondsSinceEpoch;
      await prefs.setInt(_prefsKeyLastSync, newLast);
      final dt = DateTime.now().millisecondsSinceEpoch - startMs;
      NetworkTelemetry.instance.recordCall(success: true, latencyMs: dt);

      await _updateMeshPersistenceAndLedger(toSync);

      // Opportunistically sync twin state whenever memory sync succeeds.
      final twinClient = TwinSyncClient(dio);
      await twinClient.sync();
    } catch (_) {
      // Swallow errors: sync is best-effort and should not break UX.
      final dt = DateTime.now().millisecondsSinceEpoch - startMs;
      NetworkTelemetry.instance.recordCall(success: false, latencyMs: dt);
    }
  }

  static Map<String, Object?>? _decodeOrNull(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final map = jsonDecode(json);
      if (map is Map<String, Object?>) return map;
    } catch (_) {
      // ignore
    }
    return null;
  }

  static Future<void> _updateMeshPersistenceAndLedger(
    List<dynamic> entries,
  ) async {
    try {
      final node = await NodeIdentity.load();
      final now = DateTime.now().millisecondsSinceEpoch;
      final coop = <CoopCacheEntry>[];
      final ttlMs = const Duration(days: 1).inMilliseconds;

      for (final e in entries) {
        // Entries come from SecurityMemoryDb.listRecent; we rely on its
        // public fields used elsewhere (urlHash, host, verdict, riskScore,
        // createdAtMillis).
        final urlHash = e.urlHash as String;
        final host = e.host as String;
        final verdict = e.verdict as String;
        final riskScore = (e.riskScore as num).toDouble();
        final createdAt = e.createdAtMillis as int;
        coop.add(
          CoopCacheEntry(
            urlHash: urlHash,
            host: host,
            verdict: verdict,
            riskScore: riskScore,
            ttlMillis: ttlMs,
            originNodeId: node.nodeId,
            createdAtMillis: createdAt,
          ),
        );
      }

      await MeshPersistenceHelper.persistSnapshot(
        MeshPersistenceSnapshot(coopCache: coop),
      );

      await MeshLedgerStore.append(
        'memory_sync',
        <String, Object?>{
          'node_id': node.nodeId,
          'entry_count': entries.length,
          'updated_at': now,
        },
      );
    } catch (_) {
      // Best-effort only; never break memory sync.
    }
  }
}
