import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mesh_event_bus.dart';

class TwinMeshActivity {
  TwinMeshActivity({
    required this.count,
    required this.lastHeartbeatMillis,
    required this.lastFromTwinId,
  });

  final int count;
  final int? lastHeartbeatMillis;
  final String? lastFromTwinId;
}

class TwinMeshActivityController extends StateNotifier<TwinMeshActivity> {
  TwinMeshActivityController()
      : super(TwinMeshActivity(count: 0, lastHeartbeatMillis: null, lastFromTwinId: null)) {
    _subscription = MeshEventBus.instance.stream.listen(_onEvent);
  }

  late final StreamSubscription<MeshEvent> _subscription;

  void _onEvent(MeshEvent event) {
    if (event.type != MeshEventType.discoveryNote) return;
    final payload = event.payload;
    final fromTwinId = payload['from_twin_id'] as String?;
    final body = payload['body'] as Map<String, Object?>?;
    if (fromTwinId == null || body == null) return;
    final kind = body['kind'];
    if (kind != 'twin_heartbeat') return;

    final ts = body['updated_at'] as int? ?? event.createdAtMillis;
    state = TwinMeshActivity(
      count: state.count + 1,
      lastHeartbeatMillis: ts,
      lastFromTwinId: fromTwinId,
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final twinMeshActivityProvider =
    StateNotifierProvider<TwinMeshActivityController, TwinMeshActivity>(
  (ref) => TwinMeshActivityController(),
);
