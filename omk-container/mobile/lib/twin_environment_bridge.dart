import 'environment_triggers.dart';
import 'twin_orchestrator.dart';

/// Entry points that bridge coarse app lifecycle events into the
/// twin/environment orchestration layer.
class TwinEnvironmentBridge {
  TwinEnvironmentBridge._();

  static final TwinOrchestrator _orchestrator = TwinOrchestrator();

  /// Called when the app is resumed to foreground. Uses a coarse
  /// EnvironmentSnapshot derived from local time and a generic
  /// screenType. Platform-specific integrations can refine this later.
  static Future<void> handleAppResumed() async {
    final hour = DateTime.now().hour;
    final snapshot = EnvironmentSnapshot(
      isIdle: false,
      screenType: 'other',
      localHour: hour,
    );
    final triggers = _orchestrator.asEnvironmentHandler();
    triggers.handleSnapshot(snapshot);
  }
}
