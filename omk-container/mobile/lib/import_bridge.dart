import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart' show ConvoImportScreen; // For navigation only.

/// Bridge for native import integration (clipboard watcher, share target).
///
/// Native side uses the `omk.import` MethodChannel to send incoming shared
/// URLs into Flutter. This helper listens for those events and opens the
/// Import-by-Convo flow when appropriate.
class ImportBridge {
  ImportBridge._();

  static final ImportBridge instance = ImportBridge._();

  static const _channel = MethodChannel('omk.import');

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  void init(GlobalKey<NavigatorState> navigatorKey) {
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'incomingUrl':
          final url = call.arguments as String?;
          if (url != null && url.trim().isNotEmpty) {
            _openImportScreen(url.trim());
          }
          break;
      }
      return null;
    });

    _checkInitialUrl();
  }

  Future<void> _checkInitialUrl() async {
    try {
      final url = await _channel.invokeMethod<String>('getPendingImportUrl');
      if (url != null && url.trim().isNotEmpty) {
        _openImportScreen(url.trim());
        await _channel.invokeMethod('clearPendingImportUrl');
      }
    } catch (_) {}
  }

  void _openImportScreen(String url) {
    final nav = _navigatorKey;
    if (nav == null) return;
    final state = nav.currentState;
    if (state == null) return;

    state.push(
      MaterialPageRoute(
        builder: (_) => ConvoImportScreen(initialUrl: url),
      ),
    );
  }

  /// Enable or disable the native clipboard watcher service on Android.
  Future<void> setClipboardWatcherEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setClipboardWatcherEnabled', {
        'enabled': enabled,
      });
    } catch (_) {}
  }
}
