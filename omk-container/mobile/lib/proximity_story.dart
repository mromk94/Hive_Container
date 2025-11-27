import 'twin_identity.dart';

/// Short data bursts shared when twins are physically near.
class ProximityStory {
  ProximityStory({
    required this.fromTwinId,
    required this.toTwinId,
    required this.createdAtMillis,
    required this.summary,
  });

  final String fromTwinId;
  final String toTwinId;
  final int createdAtMillis;
  final String summary;
}

class ProximityStoryBuilder {
  static ProximityStory buildSimple(
    TwinIdentity from,
    String toTwinId,
    String contextSummary,
  ) {
    return ProximityStory(
      fromTwinId: from.twinId,
      toTwinId: toTwinId,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      summary: contextSummary,
    );
  }
}
