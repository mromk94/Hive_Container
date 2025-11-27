/// Types of audio/haptic cues used for twin presence.
enum AudioCueType {
  twinNearby,
  meshStrong,
  meshWeak,
}

class AudioCuePlan {
  const AudioCuePlan({
    required this.type,
    required this.volume,
    required this.vibrationMs,
  });

  final AudioCueType type;
  final double volume; // 0-1
  final int vibrationMs;
}
