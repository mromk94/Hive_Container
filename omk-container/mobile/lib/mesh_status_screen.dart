import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_advisor.dart';
import 'connectivity_mode.dart';
import 'mesh_alerts.dart';
import 'mesh_discovery_provider.dart';
import 'mesh_event_bus.dart';
import 'node_identity.dart';
import 'twin_mesh_activity.dart';

class MeshStatusScreen extends ConsumerWidget {
  const MeshStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(meshAlertsProvider);
    final mode = ConnectivityAdvisor.currentMode();
    final peersAsync = ref.watch(allowedMeshPeersStreamProvider);
    final twinActivity = ref.watch(twinMeshActivityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh status'),
      ),
      body: FutureBuilder<NodeIdentity>(
        future: NodeIdentity.load(),
        builder: (context, snapshot) {
          final nodeId = snapshot.data?.nodeId ?? 'loading...';
          final peerCount = peersAsync.maybeWhen(
            data: (peers) => peers.length,
            orElse: () => 0,
          );
          String twinActivityText;
          if (twinActivity.count == 0) {
            twinActivityText = 'No twin heartbeats yet';
          } else {
            final ts = twinActivity.lastHeartbeatMillis != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    twinActivity.lastHeartbeatMillis!,
                  )
                : null;
            final timeStr = ts == null
                ? 'unknown time'
                : '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
            twinActivityText =
                '${twinActivity.count} heartbeat(s), last at $timeStr from ${twinActivity.lastFromTwinId ?? 'unknown'}';
          }
          final modeText = switch (mode) {
            ConnectivityMode.cloud => 'cloud',
            ConnectivityMode.localMesh => 'mesh-local',
            ConnectivityMode.offline => 'offline-local',
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Node: $nodeId'),
                    const SizedBox(height: 4),
                    Text('Mode: $modeText'),
                    const SizedBox(height: 4),
                    Text('Peers nearby: $peerCount'),
                    const SizedBox(height: 4),
                    Text('Twin mesh: $twinActivityText'),
                    const SizedBox(height: 8),
                    Text('Security alerts from mesh (local scaffolding):',
                        style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final e = alerts[alerts.length - 1 - index];
                    final ts =
                        DateTime.fromMillisecondsSinceEpoch(e.createdAtMillis);
                    final time = '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      leading: const Icon(Icons.shield, color: Colors.redAccent),
                      title: Text('Security warning from ${e.originNodeId}'),
                      subtitle: Text(
                        '${e.payload['verdict'] ?? ''} • ${e.payload['risk_score'] ?? ''} at $time',
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
