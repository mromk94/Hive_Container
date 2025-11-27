import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_handshake.dart';
import 'ar_twin_overlay.dart';
import 'audio_cues.dart';
import 'environment_mapping.dart';
import 'gesture_channel.dart';
import 'mesh_discovery_provider.dart';
import 'mesh_health_visuals.dart';
import 'mesh_peer.dart';
import 'proximity_story.dart';
import 'realm_projection.dart';
import 'twin_identity.dart';
import 'voice_commands.dart';

/// Debug view that exercises Phase 4 AR scaffolding without real ARCore/ARKit
/// bindings. This screen:
/// - builds a logical RealmScene with ARTwinEntity overlays,
/// - derives a MeshHealthStatus from discovered peers,
/// - simulates gesture, audio cue, AI handshake, proximity story, and
///   voice command intents.
class ArDebugScreen extends ConsumerWidget {
  const ArDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peersAsync = ref.watch(allowedMeshPeersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AR / Realm debug'),
      ),
      body: FutureBuilder<TwinIdentity>(
        future: TwinIdentity.load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final twinId = snapshot.data!;
          final List<MeshPeer> peers = peersAsync.maybeWhen(
            data: (p) => p,
            orElse: () => <MeshPeer>[],
          );

          // Build a simple environment map with a single plane.
          final env = EnvironmentMap(
            planes: [
              PlaneSurface(id: 'plane-1', widthMeters: 2.0, heightMeters: 1.0),
            ],
          );

          // Build AR twin overlays from mesh peers.
          final overlays = ARTwinOverlayPlanner.build(twinId, peers);
          final scene = RealmScene(sceneId: 'debug-realm', twins: overlays);

          // Compute a simple mesh health status from peers.
          final health = _computeMeshHealthStatus(peers);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Realm scene', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Scene ID: ${scene.sceneId}'),
              Text('Twins in scene: ${scene.twins.length}'),
              const SizedBox(height: 8),
              Text('Environment planes: ${env.planes.length}'),
              const Divider(height: 24),
              Text('Mesh health', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Nodes: ${health.nodeCount}'),
              Text('Avg signal: ${health.avgSignal.toStringAsFixed(2)}'),
              Text('Alert level: ${health.alertLevel.toStringAsFixed(2)}'),
              const Divider(height: 24),
              Text('Simulations', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildSimButtons(context, twinId),
            ],
          );
        },
      ),
    );
  }

  MeshHealthStatus _computeMeshHealthStatus(List<MeshPeer> peers) {
    final nodeCount = peers.length + 1; // include self
    if (peers.isEmpty) {
      return const MeshHealthStatus(nodeCount: 1, avgSignal: 0.0, alertLevel: 0.0);
    }
    double sum = 0;
    for (final dynamic p in peers) {
      final rssi = p.rssi as int;
      // Normalize RSSI (~ -90 to -30) into 0-1.
      final normalized = ((rssi + 100) / 60).clamp(0.0, 1.0);
      sum += normalized;
    }
    final avg = (sum / peers.length).clamp(0.0, 1.0);
    final alert = (1.0 - avg).clamp(0.0, 1.0);
    return MeshHealthStatus(nodeCount: nodeCount, avgSignal: avg, alertLevel: alert);
  }

  Widget _buildSimButtons(BuildContext context, TwinIdentity identity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: () {
            final intent = GestureIntent(
              type: GestureIntentType.wave,
              targetTwinId: null,
              timestampMillis: DateTime.now().millisecondsSinceEpoch,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Simulated gesture: ${intent.type}')),
            );
          },
          child: const Text('Simulate gesture intent'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            final cue = AudioCuePlan(
              type: AudioCueType.meshStrong,
              volume: 0.8,
              vibrationMs: 120,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Audio cue: ${cue.type} vol=${cue.volume.toStringAsFixed(1)} vib=${cue.vibrationMs}ms',
                ),
              ),
            );
          },
          child: const Text('Simulate audio/haptic cue'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            final now = DateTime.now().millisecondsSinceEpoch;
            final handshake = AiHandshakeEvent(
              twinIdA: identity.twinId,
              twinIdB: 'peer-twin-demo',
              createdAtMillis: now,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('AI handshake: ${handshake.twinIdA} ↔ ${handshake.twinIdB}')),
            );
          },
          child: const Text('Simulate AI handshake'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            final story = ProximityStoryBuilder.buildSimple(
              identity,
              'peer-twin-demo',
              'Met near the debug AR realm.',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Proximity story: ${story.summary}')),
            );
          },
          child: const Text('Simulate proximity story'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            final cmd = VoiceCommandIntent(
              type: VoiceCommandType.summarizeHere,
              timestampMillis: DateTime.now().millisecondsSinceEpoch,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Voice command: ${cmd.type}')),
            );
          },
          child: const Text('Simulate voice command'),
        ),
      ],
    );
  }
}
