import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'android_mesh_discovery.dart';
import 'mesh_discovery.dart';
import 'mesh_peer.dart';
import 'mesh_routing_policy.dart';

/// Provider for the current MeshDiscoveryService implementation.
/// For now this returns a NoopMeshDiscoveryService; platform-specific
/// backends can replace this in later phases.
final meshDiscoveryServiceProvider = Provider<MeshDiscoveryService>((ref) {
  MeshDiscoveryService service;
  if (Platform.isAndroid) {
    service = AndroidMeshDiscoveryService();
  } else {
    service = NoopMeshDiscoveryService();
  }
  Future.microtask(service.start);
  ref.onDispose(service.stop);
  return service;
});

/// Stream provider exposing the latest list of nearby mesh peers.
final meshPeersStreamProvider =
    StreamProvider<List<MeshPeer>>((ref) {
  final service = ref.watch(meshDiscoveryServiceProvider);
  return service.peersStream;
});

final allowedMeshPeersStreamProvider =
    StreamProvider<List<MeshPeer>>((ref) {
  final service = ref.watch(meshDiscoveryServiceProvider);
  return service.peersStream.asyncMap(MeshRoutingPolicy.filterAllowedPeers);
});
