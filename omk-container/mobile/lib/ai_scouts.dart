/// "AI Scout" missions exploring the edges of the network.
class AiScoutMission {
  AiScoutMission({
    required this.id,
    required this.originTwinId,
    required this.targetDescription,
    required this.status,
  });

  final String id;
  final String originTwinId;
  final String targetDescription;
  final String status; // e.g. 'planned' | 'running' | 'completed' | 'failed'
}
