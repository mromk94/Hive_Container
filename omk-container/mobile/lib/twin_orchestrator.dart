import 'package:dio/dio.dart';

import 'environment_triggers.dart';
import 'mesh_event_bus.dart';
import 'predictive_cache_planner.dart';
import 'security_memory_db.dart';
import 'twin_identity.dart';
import 'twin_mesh_channel.dart';
import 'twin_resonance.dart';
import 'twin_state.dart';
import 'twin_state_store.dart';
import 'twin_sync_client.dart';

/// High-level coordinator for twin-related background activities.
///
/// In this initial slice we:
/// - react to coarse EnvironmentSnapshot hints,
/// - plan pre-caching via PredictiveCachePlanner,
/// - encode that plan into TwinSnapshot.routingPrefs,
/// - opportunistically sync the updated TwinSnapshot to Hive Bridge.
class TwinOrchestrator {
  TwinOrchestrator();

  /// Handle a coarse-grained environment snapshot.
  ///
  /// This is intentionally lightweight and best-effort; failures are
  /// swallowed so UX is never blocked.
  Future<void> handleEnvironment(EnvironmentSnapshot snapshot) async {
    try {
      // 1) Plan prefetch candidates from recent security memory.
      final db = await SecurityMemoryDb.open();
      final planner = PredictiveCachePlanner(db);
      final preloadHashes = await planner.planPreload();

      // 2) Load current twin snapshot and update routingPrefs with a
      //    small, mergeable hint.
      final twin = await TwinStateStore.loadOrInit();
      final now = DateTime.now().millisecondsSinceEpoch;

      final updatedPrefs = Map<String, Object?>.from(twin.routingPrefs);
      updatedPrefs['preload_candidates.hashes'] = preloadHashes;
      updatedPrefs['preload_candidates.local_hour'] = snapshot.localHour;
      updatedPrefs['preload_candidates.screen_type'] = snapshot.screenType;

      // Record a trivial self-resonance baseline so TwinResonanceMetric is
      // exercised; real peer metrics will arrive via mesh in later phases.
      final selfResonance = TwinResonanceMetric(
        peerTwinId: twin.twinId,
        toneAlignment: 1.0,
        knowledgeOverlap: 1.0,
        awarenessSync: 1.0,
        updatedAtMillis: now,
      );
      updatedPrefs['local_only.resonance_self'] = selfResonance.toJson();

      final updatedTwin = TwinSnapshot(
        twinId: twin.twinId,
        updatedAtMillis: now,
        routingPrefs: updatedPrefs,
      );
      await TwinStateStore.save(updatedTwin);

      // 3) Best-effort sync to Hive Bridge so twin state becomes visible
      //    to backend / future peers.
      final dio = Dio();
      final client = TwinSyncClient(dio);
      await client.sync();

      // 4) Emit a lightweight twin_heartbeat message over MeshEventBus via
      //    TwinMeshChannel so that twin-level activity is visible on the
      //    mesh/offline path. This is best-effort only and does not affect UX.
      try {
        final identity = await TwinIdentity.load();
        final channel = TwinMeshChannel(MeshEventBus.instance, identity);
        channel.sendTwinMessage(
          'broadcast',
          <String, Object?>{
            'kind': 'twin_heartbeat',
            'updated_at': now,
          },
        );
      } catch (_) {
        // Ignore mesh heartbeat errors; primary twin flow already completed.
      }
    } catch (_) {
      // Best-effort only; ignore errors.
    }
  }

  /// Convenience helper to build an EnvironmentTriggers instance that
  /// forwards snapshots into this orchestrator.
  EnvironmentTriggers asEnvironmentHandler() {
    return EnvironmentTriggers(handleEnvironment);
  }
}
