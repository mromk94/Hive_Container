import 'package:flutter/material.dart';

import 'ai_villages.dart';

class AiVillagesScreen extends StatefulWidget {
  const AiVillagesScreen({super.key});

  @override
  State<AiVillagesScreen> createState() => _AiVillagesScreenState();
}

class _AiVillagesScreenState extends State<AiVillagesScreen> {
  final List<AiVillageCluster> _clusters = <AiVillageCluster>[
    AiVillageCluster(id: 'v-1', regionId: 'region-a', nodeCount: 5, activeTwinCount: 3),
    AiVillageCluster(id: 'v-2', regionId: 'region-b', nodeCount: 12, activeTwinCount: 7),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI villages (Phase 6)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Logical clusters of active OMK nodes (local mock data only).',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'This debug view lists example clusters; no map or mesh sync is wired yet.',
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _clusters.length,
                itemBuilder: (context, index) {
                  final cluster = _clusters[index];
                  return ListTile(
                    leading: const Icon(Icons.location_city_outlined),
                    title: Text('Village ${cluster.id}'),
                    subtitle: Text(
                      'Region: ${cluster.regionId}\nNodes: ${cluster.nodeCount} • Active twins: ${cluster.activeTwinCount}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
