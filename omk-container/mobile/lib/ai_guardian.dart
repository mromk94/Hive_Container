import 'mesh_event_bus.dart';
import 'node_identity.dart';
import 'security_checkpoint.dart';
import 'security_decision_flow.dart';

/// Community-local AI Guardian surface: turns high-risk decisions into
/// mesh-broadcastable alerts. Integration with actual transport will happen
/// in a later stage.
class AiGuardianService {
  AiGuardianService(this._bus, this._nodeIdentity);

  final MeshEventBus _bus;
  final NodeIdentity _nodeIdentity;

  void handleDecision(SecurityDecision decision) {
    final checkpoint = SecurityCheckpoint.evaluate(decision);
    if (checkpoint.level == SecurityAlertLevel.safe) {
      return;
    }

    final event = MeshEvent(
      type: MeshEventType.securityWarning,
      originNodeId: _nodeIdentity.nodeId,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      payload: <String, Object?>{
        'verdict': decision.verdict,
        'risk_score': decision.riskScore,
        'score_0_100': checkpoint.score,
        'path': decision.path,
      },
    );
    _bus.emit(event);
  }
}
