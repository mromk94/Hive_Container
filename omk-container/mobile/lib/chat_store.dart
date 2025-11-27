import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Simple shared store for OMK chat history.
///
/// Works with the default FlutterSharedPreferences implementation on Android.
class ChatStore {
  static const String _key = 'omk_chat_history_v1';

  /// Load raw message maps from shared preferences.
  /// Each map is expected to contain `role` and `text` keys.
  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {
      // Ignore malformed payloads in this debug build.
    }
    return [];
  }

  /// Persist message maps into shared preferences.
  static Future<void> save(List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(messages);
    await prefs.setString(_key, jsonString);
  }
}

/// Global theme preference (dark / light) shared between Flutter and
/// the native overlay bubble.
class ThemeStore {
  static const String _key = 'omk_theme_dark_v1';

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to dark theme if nothing has been stored yet.
    return prefs.getBool(_key) ?? true;
  }

  static Future<void> save(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }
}
