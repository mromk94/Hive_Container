/// Intent model for fallback SMS-based signaling.
class EmergencySmsSignal {
  EmergencySmsSignal({
    required this.toPhoneNumber,
    required this.body,
    required this.createdAtMillis,
  });

  final String toPhoneNumber;
  final String body;
  final int createdAtMillis;
}
