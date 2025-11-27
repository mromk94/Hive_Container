import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mesh_discovery_provider.dart';
import 'mesh_peer.dart';
import 'topology_evolution.dart';

class TopologyScreen extends ConsumerWidget {
  const TopologyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peersAsync = ref.watch(allowedMeshPeersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Topology (Phase 7)'),
      ),
      body: peersAsync.when(
        data: (peers) {
          final stats = _computeStats(peers);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mesh topology snapshot (local only)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Derived from currently discovered peers; no history or remote telemetry yet.',
                ),
                const SizedBox(height: 24),
                Text('Observed links: ${stats.observedLinks}'),
                const SizedBox(height: 8),
                Text('Avg pseudo-latency: ${stats.avgLatencyMs} ms'),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading peers: $e'),
        ),
      ),
    );
  }

  TopologyStats _computeStats(List<MeshPeer> peers) {
    if (peers.isEmpty) {
      return TopologyStats(observedLinks: 0, avgLatencyMs: 0);
    }
    // Simple heuristic: treat each peer as a link; derive a pseudo-latency
    // from RSSI (higher RSSI => lower latency).
    int observed = peers.length;
    double sumLatency = 0;
    for (final p in peers) {
      // RSSI is typically -90 to -30. Map to 50-500ms for this debug view.
      final rssi = p.rssi.clamp(-100, -30);
      final strength = (rssi + 100) / 70; // 0..1
      final latency = 500 - (strength * 450); // 50..500
      sumLatency += latency;
    }
    final avg = (sumLatency / peers.length).round();
    return TopologyStats(observedLinks: observed, avgLatencyMs: avg);
  }
}
