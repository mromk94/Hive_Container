/// Local event tagging — annotations for important environmental data.
class EventTag {
  EventTag({
    required this.id,
    required this.twinId,
    required this.createdAtMillis,
    required this.label,
    required this.data,
  });

  final String id;
  final String twinId;
  final int createdAtMillis;
  final String label;
  final Map<String, Object?> data;
}
