import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mesh_event_bus.dart';

class MeshAlertsController extends StateNotifier<List<MeshEvent>> {
  MeshAlertsController() : super(const []) {
    _subscription = MeshEventBus.instance.stream.listen((event) {
      if (event.type != MeshEventType.securityWarning) return;
      final next = List<MeshEvent>.from(state)..add(event);
      const max = 50;
      state = next.length > max ? next.sublist(next.length - max) : next;
    });
  }

  late final StreamSubscription<MeshEvent> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final meshAlertsProvider =
    StateNotifierProvider<MeshAlertsController, List<MeshEvent>>(
  (ref) => MeshAlertsController(),
);
