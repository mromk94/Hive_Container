/// Description of a regional mirror node (portable server or hub).
class MirrorNodeDescriptor {
  MirrorNodeDescriptor({
    required this.id,
    required this.regionId,
    required this.capacityScore,
  });

  final String id;
  final String regionId;
  final int capacityScore; // abstract score (0-100)
}
