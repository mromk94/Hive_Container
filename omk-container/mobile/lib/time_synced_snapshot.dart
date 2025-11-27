import 'context_normalization.dart';

/// Wrapper type for snapshots that are expected to be compared and
/// synchronized across devices.
class TimeSyncedSnapshot {
  TimeSyncedSnapshot({
    required this.packet,
    required this.createdAtMillis,
  });

  final SemanticPacket packet;
  final int createdAtMillis;

  Map<String, Object?> toJson() => <String, Object?>{
        'created_at': createdAtMillis,
        'semantic': packet.toJson(),
      };
}
