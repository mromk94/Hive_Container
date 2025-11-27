/// Sync policy tuning for different power/connectivity conditions.
class SyncPolicyConfig {
  const SyncPolicyConfig({
    required this.minIntervalMillis,
    required this.maxIntervalMillis,
  });

  final int minIntervalMillis;
  final int maxIntervalMillis;
}
