import 'twin_identity.dart';

/// Compact snapshot of the federated twin state that can be shared with
/// Hive Bridge or mesh peers.
class TwinSnapshot {
  TwinSnapshot({
    required this.twinId,
    required this.updatedAtMillis,
    required this.routingPrefs,
  });

  final String twinId;
  final int updatedAtMillis;

  /// Arbitrary small map of routing/preferences (e.g., weights summary,
  /// model choices, UX hints).
  final Map<String, Object?> routingPrefs;

  Map<String, Object?> toJson() => <String, Object?>{
        'twin_id': twinId,
        'updated_at': updatedAtMillis,
        'routing_prefs': routingPrefs,
      };

  static TwinSnapshot fromJson(Map<String, Object?> json) {
    return TwinSnapshot(
      twinId: json['twin_id'] as String,
      updatedAtMillis: json['updated_at'] as int,
      routingPrefs:
          (json['routing_prefs'] as Map).cast<String, Object?>(),
    );
  }
}

/// Helper for merging local and remote twin snapshots.
class TwinStateManager {
  /// Merge local and remote snapshots, preferring:
  /// - newer updatedAtMillis,
  /// - and giving local precedence for keys marked as local_only.
  static TwinSnapshot merge(TwinSnapshot local, TwinSnapshot remote) {
    if (remote.updatedAtMillis <= local.updatedAtMillis) {
      return local;
    }
    final merged = Map<String, Object?>.from(local.routingPrefs);
    remote.routingPrefs.forEach((key, value) {
      if (key.startsWith('local_only.')) {
        // Never overwrite local-only fields from remote.
        return;
      }
      merged[key] = value;
    });
    return TwinSnapshot(
      twinId: local.twinId,
      updatedAtMillis: remote.updatedAtMillis,
      routingPrefs: merged,
    );
  }

  /// Produce an incremental update payload from a newer snapshot.
  static Map<String, Object?> diff(TwinSnapshot older, TwinSnapshot newer) {
    final changed = <String, Object?>{};
    newer.routingPrefs.forEach((key, value) {
      if (older.routingPrefs[key] != value) {
        changed[key] = value;
      }
    });
    return <String, Object?>{
      'twin_id': newer.twinId,
      'base_updated_at': older.updatedAtMillis,
      'updated_at': newer.updatedAtMillis,
      'changed': changed,
    };
  }
}
