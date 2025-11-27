import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Storage model for a single imported persona pack.
class PersonaPack {
  PersonaPack({
    required this.id,
    required this.name,
    required this.sourceUrl,
    required this.createdAt,
    required this.personaJson,
    required this.active,
  });

  final String id;
  final String name;
  final String sourceUrl;
  final DateTime createdAt;
  final Map<String, dynamic> personaJson;
  final bool active;

  PersonaPack copyWith({
    String? id,
    String? name,
    String? sourceUrl,
    DateTime? createdAt,
    Map<String, dynamic>? personaJson,
    bool? active,
  }) {
    return PersonaPack(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      personaJson: personaJson ?? this.personaJson,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sourceUrl': sourceUrl,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'personaJson': personaJson,
        'active': active,
      };

  factory PersonaPack.fromJson(Map<String, dynamic> json) {
    return PersonaPack(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Imported persona',
      sourceUrl: (json['sourceUrl'] as String?) ?? '',
      createdAt: json['createdAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['createdAt'] as num).toInt(),
            )
          : DateTime.now(),
      personaJson: (json['personaJson'] as Map?) != null
          ? Map<String, dynamic>.from(json['personaJson'] as Map)
          : <String, dynamic>{},
      active: json['active'] == true,
    );
  }
}

/// Simple SharedPreferences-backed store for persona packs.
///
/// This keeps everything local to the device and uses a single JSON list
/// under one key. It is intentionally uncomplicated so that we can migrate to
/// a dedicated database later without changing callers.
class PersonaPackStore {
  PersonaPackStore._();

  static const String _key = 'omk_persona_packs_v1';

  static final PersonaPackStore instance = PersonaPackStore._();

  Future<List<PersonaPack>> _loadInternal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <PersonaPack>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => PersonaPack.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList();
      }
    } catch (_) {
      // Ignore malformed payloads in this debug build.
    }
    return <PersonaPack>[];
  }

  Future<void> _saveInternal(List<PersonaPack> packs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(packs.map((p) => p.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  /// Load all persona packs once.
  Future<List<PersonaPack>> loadAll() => _loadInternal();

  /// Persist a pack. If an entry with the same id exists, it is replaced.
  Future<void> save(PersonaPack pack) async {
    final current = await _loadInternal();
    final idx = current.indexWhere((p) => p.id == pack.id);
    if (idx == -1) {
      current.add(pack);
    } else {
      current[idx] = pack;
    }
    await _saveInternal(current);
  }

  /// Delete a persona pack by id.
  Future<void> delete(String id) async {
    final current = await _loadInternal();
    current.removeWhere((p) => p.id == id);
    await _saveInternal(current);
  }

  /// Toggle the `active` flag for a specific persona pack.
  Future<void> setActive(String id, bool active) async {
    final current = await _loadInternal();
    final updated = [
      for (final p in current)
        if (p.id == id)
          p.copyWith(active: active)
        else
          p,
    ];
    await _saveInternal(updated);
  }
}
