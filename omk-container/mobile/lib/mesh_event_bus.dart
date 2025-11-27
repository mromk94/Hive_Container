import 'dart:async';

enum MeshEventType { securityWarning, weatherAlert, discoveryNote }

class MeshEvent {
  MeshEvent({
    required this.type,
    required this.originNodeId,
    required this.createdAtMillis,
    required this.payload,
  });

  final MeshEventType type;
  final String originNodeId;
  final int createdAtMillis;
  final Map<String, Object?> payload;
}

/// Local event bus for AI/mesh events. Transport-specific layers can subscribe
/// to this and forward selected events over L-Mesh.
class MeshEventBus {
  MeshEventBus._();

  static final MeshEventBus instance = MeshEventBus._();

  final StreamController<MeshEvent> _controller =
      StreamController<MeshEvent>.broadcast();

  Stream<MeshEvent> get stream => _controller.stream;

  void emit(MeshEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }
}
