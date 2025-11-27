import 'package:dio/dio.dart';

import 'content_fingerprint.dart';
import 'context_channel.dart';
import 'context_normalization.dart';
import 'memory_sync.dart';
import 'security_decision_flow.dart';
import 'security_memory_db.dart';
import 'state.dart';
import 'url_utils.dart';
import 'ai_guardian.dart';
import 'mesh_event_bus.dart';
import 'mesh_packet_builder.dart';
import 'node_identity.dart';
import 'time_synced_snapshot.dart';

/// Build a SecurityContextInput from live context (CCE) + current chat.
Future<SecurityDecision> analyzeCurrentContext(List<ChatMessage> messages) async {
  // Fetch latest sanitized context from native ContextCaptureEngine.
  ContextSnapshot cceSnapshot;
  try {
    cceSnapshot = await OmkContextChannel.getSnapshot();
  } catch (_) {
    // If the native plugin fails, fall back to an empty snapshot to
    // avoid crashing the quick action.
    cceSnapshot = ContextSnapshot(
      appPackage: null,
      appLabel: null,
      textSnippets: const [],
      screenshotHash: null,
    );
  }

  // In this build we still use a placeholder URL, but we combine CCE text
  // with user chat messages to approximate page context.
  const rawUrl = 'https://example.com/mock';
  final canon = canonicalizeUrl(rawUrl);

  final userTexts = messages
      .where((m) => m.role == 'user')
      .map((m) => m.text)
      .toList(growable: false);

  final combinedSnippets = <String>{
    ...cceSnapshot.textSnippets,
    ...userTexts,
  }.where((s) => s.trim().isNotEmpty).toList(growable: false);

  // Build a semantic packet for higher-level reasoning / logging,
  // but only if context meaningfully changed since the last call.
  final packet = ContextNormalizationLayer.buildIfChanged(
    cce: cceSnapshot,
    messages: messages,
    source: 'mini_chat',
    actionType: 'analyze_page',
  );

  final input = SecurityContextInput(
    urlHash: canon.hash,
    host: canon.host,
    textSnippets: combinedSnippets,
  );

  final engine = SecurityDecisionEngine(dio: Dio());
  final decision = await engine.decide(input);

  // Ensure the most recent snapshot is visible in the cache with a fingerprint.
  final db = await SecurityMemoryDb.open();
  final fingerprint = buildFingerprint(
    rawUrl: rawUrl,
    pageTitle: cceSnapshot.appLabel ?? 'Unknown context',
    screenshotPhash: cceSnapshot.screenshotHash ?? '0',
  );
  await db.upsertFromSnapshot(
    urlHash: canon.hash,
    host: canon.host,
    riskScore: decision.riskScore,
    verdict: decision.verdict,
    source: 'analyze_action',
    ttl: const Duration(days: 30),
    fingerprint: fingerprint.toJson(),
    snapshot: packet?.toJson(),
  );

  // Emit community-local security alerts via AiGuardianService. This uses
  // mesh scaffolding only; no transport is wired yet.
  final node = await NodeIdentity.load();
  final guardian = AiGuardianService(MeshEventBus.instance, node);
  guardian.handleDecision(decision);

  // Broadcast a TimeSyncedSnapshot over MeshEventBus so L-Mesh transports
  // (via MeshTransportBridge + OfflineEnvelopeStore) can forward context to
  // nearby peers once native mesh is wired.
  if (packet != null) {
    final snapshot = TimeSyncedSnapshot(
      packet: packet,
      createdAtMillis: packet.timestampMillis,
    );
    final meshPacket = MeshPacketBuilder.build(snapshot: snapshot);
    MeshEventBus.instance.emit(
      MeshEvent(
        type: MeshEventType.securityWarning,
        originNodeId: node.nodeId,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
        payload: meshPacket,
      ),
    );
  }

  // Best-effort background sync of processed context to Hive Bridge.
  await MemorySyncClient.syncPending(Dio());

  return decision;
}
