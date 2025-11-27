import 'dart:io';

import 'package:flutter/services.dart';

class OverlayBridge {
  static const MethodChannel _channel = MethodChannel('omk.overlay');
  static void Function()? _onOverlayTapped;

  static Future<bool> isOverlayAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isOverlayAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> ensureOverlayEnabled() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final granted = await isOverlayAvailable();
      if (granted) {
        return true;
      }
      await _channel.invokeMethod('openOverlaySettings');
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> startOverlay() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startOverlay');
    } catch (_) {}
  }

  static Future<void> stopOverlay() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopOverlay');
    } catch (_) {}
  }

  static void registerOverlayTappedHandler(void Function() handler) {
    _onOverlayTapped = handler;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'overlayTapped') {
        final cb = _onOverlayTapped;
        if (cb != null) cb();
      }
    });
  }
}
