/// Regional mesh-to-cloud sync gateway description.
class RegionalGatewayState {
  RegionalGatewayState({
    required this.regionId,
    required this.lastSyncMillis,
    required this.reachable,
  });

  final String regionId;
  final int lastSyncMillis;
  final bool reachable;
}
