import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineEnvelope {
  OfflineEnvelope({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAtMillis,
    required this.retries,
  });

  final String id;
  final String type; // e.g. 'memory_sync', 'mesh_event'
  final Map<String, Object?> payload;
  final int createdAtMillis;
  final int retries;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'payload': payload,
        'created_at': createdAtMillis,
        'retries': retries,
      };

  static OfflineEnvelope fromJson(Map<String, Object?> json) {
    return OfflineEnvelope(
      id: json['id'] as String,
      type: json['type'] as String,
      payload: (json['payload'] as Map).cast<String, Object?>(),
      createdAtMillis: json['created_at'] as int,
      retries: json['retries'] as int,
    );
  }
}

/// Minimal store-then-forward queue for offline operations.
class OfflineEnvelopeStore {
  OfflineEnvelopeStore._();

  static const _key = 'offline_envelopes';

  static Future<List<OfflineEnvelope>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <OfflineEnvelope>[];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .cast<Map<String, Object?>>()
        .map(OfflineEnvelope.fromJson)
        .toList(growable: true);
  }

  static Future<void> saveAll(List<OfflineEnvelope> envelopes) async {
    final prefs = await SharedPreferences.getInstance();
    final list = envelopes.map((e) => e.toJson()).toList(growable: false);
    await prefs.setString(_key, jsonEncode(list));
  }

  static Future<void> enqueue(OfflineEnvelope envelope) async {
    final list = await loadAll();
    list.add(envelope);
    await saveAll(list);
  }

  static Future<List<OfflineEnvelope>> drainUpTo(int maxCount) async {
    final list = await loadAll();
    if (list.isEmpty) return list;
    final take = list.take(maxCount).toList(growable: false);
    final remaining = list.skip(maxCount).toList(growable: false);
    await saveAll(remaining);
    return take;
  }
}
