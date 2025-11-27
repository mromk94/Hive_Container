import 'node_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Federated AI twin identity, derived from node identity but stable
/// across mesh/cloud sync.
class TwinIdentity {
  TwinIdentity({
    required this.twinId,
    required this.node,
  });

  final String twinId;
  final NodeIdentity node;

  static const _keyTwinId = 'omk_twin_id';

  static Future<TwinIdentity> load() async {
    final node = await NodeIdentity.load();
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_keyTwinId);
    if (id == null || id.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      id = 'twin-${node.nodeId}-$now';
      await prefs.setString(_keyTwinId, id);
    }
    return TwinIdentity(twinId: id, node: node);
  }
}
