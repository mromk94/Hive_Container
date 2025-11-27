import 'mesh_event_bus.dart';
import 'twin_identity.dart';

/// Simple twin-to-twin messaging abstraction built on top of MeshEventBus.
/// Transport-specific layers can encode/decode these messages over L-Mesh.
class TwinMeshChannel {
  TwinMeshChannel(this._bus, this._identity);

  final MeshEventBus _bus;
  final TwinIdentity _identity;

  void sendTwinMessage(String targetTwinId, Map<String, Object?> body) {
    _bus.emit(
      MeshEvent(
        type: MeshEventType.discoveryNote,
        originNodeId: _identity.node.nodeId,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
        payload: <String, Object?>{
          'from_twin_id': _identity.twinId,
          'to_twin_id': targetTwinId,
          'body': body,
        },
      ),
    );
  }
}
