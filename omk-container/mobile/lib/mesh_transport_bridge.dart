import 'dart:async';

import 'mesh_event_bus.dart';
import 'mesh_transport_adapter.dart';
import 'network_telemetry.dart';
import 'offline_envelope_store.dart';
import 'packet_scheduling.dart';

/// Bridge that listens to MeshEventBus and enqueues mesh events into the
/// OfflineEnvelopeStore for future forwarding over real transports.
class MeshTransportBridge {
  MeshTransportBridge._() {
    _subscription = MeshEventBus.instance.stream.listen((event) async {
      final sched =
          PacketScheduler.decide(NetworkTelemetry.instance.current);
      final envelope = OfflineEnvelope(
        id: 'mesh-${event.createdAtMillis}-${event.originNodeId}',
        type: 'mesh_event',
        payload: <String, Object?>{
          'type': event.type.name,
          'origin_node_id': event.originNodeId,
          'created_at': event.createdAtMillis,
          'payload': event.payload,
          'priority': sched.priority.name,
          'compressed': sched.compress,
          'transport_hint': MeshTransportRegistry.adapter.type.name,
        },
        createdAtMillis: event.createdAtMillis,
        retries: 0,
      );
      await OfflineEnvelopeStore.enqueue(envelope);
      // Best-effort hook into the current mesh transport adapter. This remains
      // a no-op until a real WiFi Direct / BLE implementation is plugged in.
      await MeshTransportRegistry.adapter.send(envelope);
    });
  }

  late final StreamSubscription _subscription;

  static final MeshTransportBridge instance = MeshTransportBridge._();
}
