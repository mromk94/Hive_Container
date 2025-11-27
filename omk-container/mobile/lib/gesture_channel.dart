/// High-level gesture intents detected in AR space.
enum GestureIntentType {
  wave,
  point,
  connect,
}

class GestureIntent {
  GestureIntent({
    required this.type,
    required this.targetTwinId,
    required this.timestampMillis,
  });

  final GestureIntentType type;
  final String? targetTwinId;
  final int timestampMillis;
}
