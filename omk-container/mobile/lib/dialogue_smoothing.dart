/// Latency-adaptive dialogue smoothing profile for offline emulation.
class DialogueSmoothingProfile {
  const DialogueSmoothingProfile({
    required this.targetLatencyMs,
    required this.chunkSizeChars,
  });

  final int targetLatencyMs;
  final int chunkSizeChars;
}
