/// Offline voice command intent types for twin control.
enum VoiceCommandType {
  summon,
  dismiss,
  summarizeHere,
  checkSafety,
}

class VoiceCommandIntent {
  VoiceCommandIntent({
    required this.type,
    required this.timestampMillis,
  });

  final VoiceCommandType type;
  final int timestampMillis;
}
