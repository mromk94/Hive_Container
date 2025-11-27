import 'context_normalization.dart';
import 'security_checkpoint.dart';
import 'security_decision_flow.dart';
import 'autonomy_engine.dart';
import 'connectivity_advisor.dart';
import 'connectivity_mode.dart';
import 'predictive_routing.dart';

/// Types of intents the router can dispatch.
enum IntentType { security, summarization, recommendation }

class IntentTask {
  IntentTask({
    required this.type,
    required this.priority,
  });

  final IntentType type;
  final double priority; // higher = earlier
}

/// Intent Router — decides which AI function(s) to call next.
///
/// This class does not perform the AI calls itself; instead, it produces a
/// prioritized plan that a higher-level orchestrator can execute.
class IntentRouter {
  /// Initial plan based only on the semantic packet and connectivity mode.
  ///
  /// Example:
  /// - For analyze_page from mini_chat, security gets highest priority.
  /// - Summarization is queued with lower priority.
  static List<IntentTask> planFromPacket(
    SemanticPacket packet,
    ConnectivityMode initialMode,
  ) {
    final tasks = <IntentTask>[];
    final currentMode = ConnectivityAdvisor.currentMode();
    final routingHint = RoutingHint(
      mode: currentMode,
      confidence: switch (currentMode) {
        ConnectivityMode.cloud => 1.0,
        ConnectivityMode.localMesh => 0.7,
        ConnectivityMode.offline => 0.3,
      },
    );

    // Security intent is primary for analyze_page / suspicious wording.
    double securityPriority = 0.5 + packet.intentConfidence * 0.5;
    if (packet.actionType == 'analyze_page') {
      securityPriority = 1.0;
    }

    tasks.add(
      IntentTask(
        type: IntentType.security,
        priority: securityPriority * AutonomyEngine.weightFor(IntentType.security),
      ),
    );

    // Summarization is generally useful but secondary.
    // Summarization is generally useful but secondary. When offline,
    // de-prioritize it to conserve resources.
    double summarizationBase = (securityPriority - 0.2).clamp(0.0, 1.0);
    if (currentMode == ConnectivityMode.offline) {
      summarizationBase *= 0.3;
    }
    summarizationBase *= routingHint.confidence;
    tasks.add(
      IntentTask(
        type: IntentType.summarization,
        priority:
            summarizationBase * AutonomyEngine.weightFor(IntentType.summarization),
      ),
    );

    // Recommendation (e.g., what to do next) is lowest priority by default.
    // Recommendation is lowest priority; when offline, suppress it further.
    double recommendationBase = 0.2;
    if (currentMode == ConnectivityMode.offline) {
      recommendationBase *= 0.3;
    }
    recommendationBase *= routingHint.confidence;
    tasks.add(
      IntentTask(
        type: IntentType.recommendation,
        priority:
            recommendationBase * AutonomyEngine.weightFor(IntentType.recommendation),
      ),
    );

    tasks.sort((a, b) => b.priority.compareTo(a.priority));
    return tasks;
  }

  /// Refines the plan after a security decision is known.
  ///
  /// - If ALERT, security remains and summarization is deprioritized.
  /// - If SAFE, summarization is promoted.
  static List<IntentTask> refineAfterSecurity({
    required List<IntentTask> existing,
    required SecurityDecision decision,
  }) {
    final checkpoint = SecurityCheckpoint.evaluate(decision);
    final updated = <IntentTask>[];

    for (final task in existing) {
      double p = task.priority;
      switch (task.type) {
        case IntentType.security:
          // Keep security high if alert/warn; slightly reduce on safe.
          if (checkpoint.level == SecurityAlertLevel.safe) {
            p *= 0.8;
          } else {
            p = 1.0;
          }
          break;
        case IntentType.summarization:
          if (checkpoint.level == SecurityAlertLevel.safe) {
            p = 0.9; // promote summaries when safe
          } else if (checkpoint.level == SecurityAlertLevel.warn) {
            p = 0.5; // still useful, but secondary
          } else {
            p = 0.1; // de-prioritize when in ALERT state
          }
          break;
        case IntentType.recommendation:
          // Recommendations become more important in WARN/ALERT to offer
          // next steps, but still behind core security handling.
          if (checkpoint.level == SecurityAlertLevel.alert) {
            p = 0.8;
          } else if (checkpoint.level == SecurityAlertLevel.warn) {
            p = 0.6;
          }
          break;
      }
      updated.add(IntentTask(type: task.type, priority: p));
    }

    updated.sort((a, b) => b.priority.compareTo(a.priority));
    return updated;
  }
}
