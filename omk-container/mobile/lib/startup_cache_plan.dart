/// Multi-layer caching plan to speed up twin boot-up.
class StartupCachePlan {
  const StartupCachePlan({
    required this.loadSecurityMemory,
    required this.loadCoopCache,
    required this.loadTwinSnapshot,
  });

  final bool loadSecurityMemory;
  final bool loadCoopCache;
  final bool loadTwinSnapshot;
}
