import 'offline_envelope_store.dart';

/// Offline security ticket for reporting suspicious activity.
class SecurityTicket {
  SecurityTicket({
    required this.id,
    required this.createdAtMillis,
    required this.severity,
    required this.summary,
  });

  final String id;
  final int createdAtMillis;
  final String severity; // e.g. 'low' | 'medium' | 'high'
  final String summary;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'created_at': createdAtMillis,
        'severity': severity,
        'summary': summary,
      };
}

class SecurityTicketing {
  static Future<void> enqueueTicket(SecurityTicket ticket) async {
    final env = OfflineEnvelope(
      id: ticket.id,
      type: 'security_ticket',
      payload: ticket.toJson(),
      createdAtMillis: ticket.createdAtMillis,
      retries: 0,
    );
    await OfflineEnvelopeStore.enqueue(env);
  }
}
