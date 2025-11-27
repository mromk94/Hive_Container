/// Placeholder for environment-derived triggers (time of day, idle state,
/// screen type, etc.). Platform-specific integrations will feed real data
/// into this model in later stages.
class EnvironmentSnapshot {
  const EnvironmentSnapshot({
    required this.isIdle,
    required this.screenType,
    required this.localHour,
  });

  final bool isIdle;
  final String screenType; // e.g. 'browser', 'video', 'doc', 'other'
  final int localHour;
}

class EnvironmentTriggers {
  EnvironmentTriggers(this._onTrigger);

  final void Function(EnvironmentSnapshot) _onTrigger;

  void handleSnapshot(EnvironmentSnapshot snapshot) {
    _onTrigger(snapshot);
  }
}
