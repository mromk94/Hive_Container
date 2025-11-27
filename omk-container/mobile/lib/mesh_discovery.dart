import 'dart:async';

import 'mesh_peer.dart';

/// Abstract discovery service. Platform-specific implementations (Android/iOS)
/// will plug WiFi Direct and BLE scanning into this interface.
abstract class MeshDiscoveryService {
  Stream<List<MeshPeer>> get peersStream;

  Future<void> start();
  Future<void> stop();
}

/// No-op implementation used in builds where mesh is not yet wired.
class NoopMeshDiscoveryService implements MeshDiscoveryService {
  NoopMeshDiscoveryService();

  final StreamController<List<MeshPeer>> _controller =
      StreamController<List<MeshPeer>>.broadcast();

  @override
  Stream<List<MeshPeer>> get peersStream => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
