import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'mesh_ledger.dart';

/// Simple local store for MeshLedgerEntry objects backed by SharedPreferences.
///
/// This is an append-only log used for auditing mesh-related operations such
/// as memory syncs and offline forwarding. It is not used for any critical
/// control flow.
class MeshLedgerStore {
  static const _key = 'mesh_ledger_entries';

  static Future<void> append(
    String type,
    Map<String, Object?> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    List<dynamic> list;
    if (raw == null || raw.isEmpty) {
      list = <dynamic>[];
    } else {
      try {
        list = jsonDecode(raw) as List<dynamic>;
      } catch (_) {
        list = <dynamic>[];
      }
    }

    final last = list.isNotEmpty ? list.last as Map<String, dynamic> : null;
    final prevHash = last != null ? (last['hash'] as String? ?? '') : '';

    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = MeshLedgerEntry(
      id: '$type-$now',
      prevHash: prevHash,
      payload: <String, Object?>{
        'kind': type,
        ...payload,
      },
      createdAtMillis: now,
    );
    final hash = entry.computeHash();

    list.add(<String, Object?>{
      'id': entry.id,
      'prev_hash': entry.prevHash,
      'payload': entry.payload,
      'created_at': entry.createdAtMillis,
      'hash': hash,
    });

    await prefs.setString(_key, jsonEncode(list));
  }
}
