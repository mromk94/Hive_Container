import 'package:shared_preferences/shared_preferences.dart';

/// Manages locally approved and banned node IDs.
class NodeQuarantineManager {
  NodeQuarantineManager._();

  static const _keyApproved = 'omk_approved_nodes';
  static const _keyBanned = 'omk_banned_nodes';

  static Future<Set<String>> _loadSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? <String>[];
    return list.toSet();
  }

  static Future<void> _saveSet(String key, Set<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value.toList(growable: false));
  }

  static Future<void> approveNode(String nodeId) async {
    final approved = await _loadSet(_keyApproved);
    final banned = await _loadSet(_keyBanned);
    banned.remove(nodeId);
    approved.add(nodeId);
    await _saveSet(_keyApproved, approved);
    await _saveSet(_keyBanned, banned);
  }

  static Future<void> banNode(String nodeId) async {
    final approved = await _loadSet(_keyApproved);
    final banned = await _loadSet(_keyBanned);
    approved.remove(nodeId);
    banned.add(nodeId);
    await _saveSet(_keyApproved, approved);
    await _saveSet(_keyBanned, banned);
  }

  static Future<bool> isApproved(String nodeId) async {
    final approved = await _loadSet(_keyApproved);
    return approved.contains(nodeId);
  }

  static Future<bool> isBanned(String nodeId) async {
    final banned = await _loadSet(_keyBanned);
    return banned.contains(nodeId);
  }
}
