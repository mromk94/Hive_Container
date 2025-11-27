import 'package:flutter/material.dart';

import 'memory_sync.dart';
import 'network_telemetry.dart';
import 'packet_scheduling.dart';

class SyncPolicyScreen extends StatelessWidget {
  const SyncPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final policy = MemorySyncClient.policy;
    final telemetry = NetworkTelemetry.instance.current;
    final sched = PacketScheduler.decide(telemetry);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync policy (Phase 7)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Memory sync policy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Min interval: ${policy.minIntervalMillis} ms'),
            Text('Max interval: ${policy.maxIntervalMillis} ms'),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Current packet scheduling',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Priority: ${sched.priority.name}'),
            Text('Compressed: ${sched.compress}'),
          ],
        ),
      ),
    );
  }
}
