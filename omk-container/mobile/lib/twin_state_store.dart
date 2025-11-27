import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'twin_identity.dart';
import 'twin_state.dart';

/// Simple persistence for TwinSnapshot using SharedPreferences.
class TwinStateStore {
  TwinStateStore._();

  static const _key = 'omk_twin_snapshot';

  static Future<TwinSnapshot> loadOrInit() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, Object?>;
        return TwinSnapshot.fromJson(map);
      } catch (_) {
        // fall through to init
      }
    }
    final id = await TwinIdentity.load();
    final now = DateTime.now().millisecondsSinceEpoch;
    final snap = TwinSnapshot(
      twinId: id.twinId,
      updatedAtMillis: now,
      routingPrefs: <String, Object?>{},
    );
    await save(snap);
    return snap;
  }

  static Future<void> save(TwinSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(snapshot.toJson()));
  }
}
