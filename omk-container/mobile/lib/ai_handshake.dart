/// Cross-user synchronization moment when twins meet.
class AiHandshakeEvent {
  AiHandshakeEvent({
    required this.twinIdA,
    required this.twinIdB,
    required this.createdAtMillis,
  });

  final String twinIdA;
  final String twinIdB;
  final int createdAtMillis;
}
