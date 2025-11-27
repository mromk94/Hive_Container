import 'dart:io';

import 'package:flutter/services.dart';

import 'offline_envelope_store.dart';

/// Logical mesh transport adapters. Real WiFi Direct / BLE stacks can
/// implement this interface in platform-specific code; for now we provide
/// adapters that either call into Android or no-op elsewhere.
enum MeshAdapterType { wifiDirect, ble }

abstract class MeshTransportAdapter {
  MeshAdapterType get type;

  Future<void> send(OfflineEnvelope envelope);
}

class WifiDirectMeshTransportAdapter implements MeshTransportAdapter {
  const WifiDirectMeshTransportAdapter();

  static const MethodChannel _channel = MethodChannel('omk.mesh.transport');

  @override
  MeshAdapterType get type => MeshAdapterType.wifiDirect;

  @override
  Future<void> send(OfflineEnvelope envelope) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('sendMeshPayload', <String, Object?>{
        'id': envelope.id,
        'type': envelope.type,
        'created_at': envelope.createdAtMillis,
        'payload': envelope.payload,
      });
    } catch (_) {
      // Best-effort only; errors here should not affect primary flows.
    }
  }
}

class BleMeshTransportAdapter implements MeshTransportAdapter {
  const BleMeshTransportAdapter();

  @override
  MeshAdapterType get type => MeshAdapterType.ble;

  @override
  Future<void> send(OfflineEnvelope envelope) async {
    // Placeholder for future BLE transport; currently no-op.
  }
}

/// Global hook for the current mesh transport adapter.
class MeshTransportRegistry {
  static MeshTransportAdapter adapter =
      Platform.isAndroid ? const WifiDirectMeshTransportAdapter() : const BleMeshTransportAdapter();
}
