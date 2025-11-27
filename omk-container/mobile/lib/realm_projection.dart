import 'ar_twin_overlay.dart';

/// Shared scene description for a local "Realm" projection.
class RealmScene {
  RealmScene({
    required this.sceneId,
    required this.twins,
  });

  final String sceneId;
  final List<ARTwinEntity> twins;
}
