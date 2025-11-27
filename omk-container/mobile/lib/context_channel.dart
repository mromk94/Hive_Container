import 'package:flutter/services.dart';

class ContextSnapshot {
  ContextSnapshot({
    required this.appPackage,
    required this.appLabel,
    required this.textSnippets,
    required this.screenshotHash,
  });

  final String? appPackage;
  final String? appLabel;
  final List<String> textSnippets;
  final String? screenshotHash;

  factory ContextSnapshot.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return ContextSnapshot(
        appPackage: null,
        appLabel: null,
        textSnippets: const [],
        screenshotHash: null,
      );
    }
    final rawSnippets = map['textSnippets'] as List<dynamic>? ?? const [];
    return ContextSnapshot(
      appPackage: map['appPackage'] as String?,
      appLabel: map['appLabel'] as String?,
      textSnippets: rawSnippets.map((e) => e.toString()).toList(growable: false),
      screenshotHash: map['screenshotHash'] as String?,
    );
  }
}

class OmkContextChannel {
  static const MethodChannel _channel = MethodChannel('omk_container/context');

  static Future<ContextSnapshot> getSnapshot() async {
    final map = await _channel.invokeMethod<dynamic>('getSnapshot');
    if (map is Map) {
      return ContextSnapshot.fromMap(map as Map<dynamic, dynamic>);
    }
    return ContextSnapshot.fromMap(null);
  }

  static Future<void> clear() async {
    await _channel.invokeMethod('clear');
  }
}
