/// Distributed "learning pulse" cycles to blend community knowledge.
class LearningPulseCycle {
  LearningPulseCycle({
    required this.id,
    required this.startedAtMillis,
    this.completedAtMillis,
    required this.participantTwinIds,
  });

  final String id;
  final int startedAtMillis;
  final int? completedAtMillis;
  final List<String> participantTwinIds;
}
