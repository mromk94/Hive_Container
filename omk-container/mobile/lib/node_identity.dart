import 'package:shared_preferences/shared_preferences.dart';

/// Logical role of this OMK Container node within the hybrid grid.
enum NodeRole { leaf, relay, gateway }

/// Minimal node identity used for mesh/topology descriptions.
class NodeIdentity {
  NodeIdentity({
    required this.nodeId,
    required this.role,
  });

  final String nodeId;
  final NodeRole role;

  static const _keyNodeId = 'omk_node_id';
  static const _keyRole = 'omk_node_role';

  /// Loads or creates a pseudo-anonymous node identity.
  static Future<NodeIdentity> load({NodeRole defaultRole = NodeRole.leaf}) async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_keyNodeId);
    if (id == null || id.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      id = 'node-$now-${now.hashCode & 0xffff}';
      await prefs.setString(_keyNodeId, id);
    }
    final roleIndex = prefs.getInt(_keyRole) ?? defaultRole.index;
    final role = NodeRole.values[roleIndex];
    return NodeIdentity(nodeId: id, role: role);
  }

  Future<void> saveRole(NodeRole newRole) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRole, newRole.index);
  }
}
