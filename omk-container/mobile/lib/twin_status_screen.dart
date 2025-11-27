import 'package:flutter/material.dart';

import 'twin_state.dart';
import 'twin_state_store.dart';

/// Read-only view of the current TwinSnapshot for debugging and Phase 3
/// observability. Surfaces twin_id, last update time, and a compact
/// summary of routingPrefs.
class TwinStatusScreen extends StatelessWidget {
  const TwinStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twin status'),
      ),
      body: FutureBuilder<TwinSnapshot>(
        future: TwinStateStore.loadOrInit(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final twin = snapshot.data!;
          final prefs = twin.routingPrefs;
          final updatedAt = DateTime.fromMillisecondsSinceEpoch(
            twin.updatedAtMillis,
          );

          final preload = prefs['preload_candidates.hashes'];
          final preloadList =
              (preload is List) ? preload.cast<Object?>() : const <Object?>[];
          final screenType = prefs['preload_candidates.screen_type'];
          final hour = prefs['preload_candidates.local_hour'];
          final selfResonanceJson =
              prefs['local_only.resonance_self'] as Map<String, Object?>?;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Twin ID', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(twin.twinId),
              const SizedBox(height: 12),
              Text('Last updated',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(updatedAt.toLocal().toString()),
              const SizedBox(height: 16),
              Text('Preload planner',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Candidates: ${preloadList.length}'),
              if (screenType != null) ...[
                const SizedBox(height: 2),
                Text('Screen type: $screenType'),
              ],
              if (hour != null) ...[
                const SizedBox(height: 2),
                Text('Local hour: $hour'),
              ],
              const SizedBox(height: 16),
              Text('Self resonance',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              if (selfResonanceJson == null)
                const Text('No resonance metrics recorded yet.')
              else ...[
                Text(
                  'tone=${selfResonanceJson['tone_alignment']}  '
                  'knowledge=${selfResonanceJson['knowledge_overlap']}  '
                  'awareness=${selfResonanceJson['awareness_sync']}',
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
