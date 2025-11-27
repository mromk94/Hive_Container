import 'package:flutter/material.dart';

import 'community_milestones.dart';

class CommunityMilestonesScreen extends StatefulWidget {
  const CommunityMilestonesScreen({super.key});

  @override
  State<CommunityMilestonesScreen> createState() => _CommunityMilestonesScreenState();
}

class _CommunityMilestonesScreenState extends State<CommunityMilestonesScreen> {
  CommunityMilestones _milestones = CommunityMilestones(
    hiveLevel: 1,
    meshReach: 0,
    uptimeScore: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community milestones (Phase 6)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gamified community metrics for this node only',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Values here are local and in-memory; no mesh/cloud aggregation yet.',
            ),
            const SizedBox(height: 24),
            _buildMetricRow(
              context,
              label: 'Hive level',
              value: _milestones.hiveLevel.toString(),
              onIncrement: () => _update(hiveDelta: 1),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              context,
              label: 'Mesh reach',
              value: _milestones.meshReach.toString(),
              onIncrement: () => _update(reachDelta: 10),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              context,
              label: 'Uptime score',
              value: '${_milestones.uptimeScore} / 100',
              onIncrement: () => _update(uptimeDelta: 5),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _milestones = CommunityMilestones(
                    hiveLevel: 1,
                    meshReach: 0,
                    uptimeScore: 0,
                  );
                });
              },
              child: const Text('Reset metrics'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onIncrement,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(value),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onIncrement,
        ),
      ],
    );
  }

  void _update({int hiveDelta = 0, int reachDelta = 0, int uptimeDelta = 0}) {
    setState(() {
      final newHive = (_milestones.hiveLevel + hiveDelta).clamp(1, 9999);
      final newReach = (_milestones.meshReach + reachDelta).clamp(0, 1000000);
      final newUptime = (_milestones.uptimeScore + uptimeDelta).clamp(0, 100);
      _milestones = CommunityMilestones(
        hiveLevel: newHive,
        meshReach: newReach,
        uptimeScore: newUptime,
      );
    });
  }
}
