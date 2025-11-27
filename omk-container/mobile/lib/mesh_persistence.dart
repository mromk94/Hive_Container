import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'coop_cache.dart';

/// High-level description of what should be persisted for the mesh.
class MeshPersistenceSnapshot {
  MeshPersistenceSnapshot({
    required this.coopCache,
  });

  final List<CoopCacheEntry> coopCache;
}

/// Placeholder for mesh persistence helpers that will be backed by
/// durable storage in a later phase.
class MeshPersistenceHelper {
  static Future<void> persistSnapshot(MeshPersistenceSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final coop = snapshot.coopCache
        .map((e) => e.toJson())
        .toList(growable: false);
    final json = jsonEncode(<String, Object?>{
      'coop_cache': coop,
    });
    await prefs.setString('mesh_persistence_snapshot', json);
  }

  static Future<MeshPersistenceSnapshot> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mesh_persistence_snapshot');
    if (raw == null || raw.isEmpty) {
      return MeshPersistenceSnapshot(coopCache: <CoopCacheEntry>[]);
    }
    try {
      final map = jsonDecode(raw) as Map<String, Object?>;
      final list = (map['coop_cache'] as List<dynamic>? ?? const [])
          .cast<Map<String, Object?>>();
      final entries = list
          .map(CoopCacheEntry.fromJson)
          .toList(growable: false);
      return MeshPersistenceSnapshot(coopCache: entries);
    } catch (_) {
      return MeshPersistenceSnapshot(coopCache: <CoopCacheEntry>[]);
    }
  }
}
