/// Group problem-solving session descriptor.
class GroupProblemSession {
  GroupProblemSession({
    required this.id,
    required this.topic,
    required this.participantTwinIds,
    required this.createdAtMillis,
    required this.status,
  });

  final String id;
  final String topic;
  final List<String> participantTwinIds;
  final int createdAtMillis;
  final String status; // e.g. 'open' | 'in_progress' | 'completed'
}
