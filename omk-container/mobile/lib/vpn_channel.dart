import 'package:flutter/services.dart';

/// Thin Dart wrapper around the native OMK VPN plugin.
class OmkVpnChannel {
  static const MethodChannel _channel = MethodChannel('omk_container/vpn');

  static Future<void> startVpn() async {
    await _channel.invokeMethod('startVpn');
  }

  static Future<void> stopVpn() async {
    await _channel.invokeMethod('stopVpn');
  }

  static Future<void> setDeepAnalysis(bool enabled) async {
    await _channel.invokeMethod('setDeepAnalysis', {
      'enabled': enabled,
    });
  }
}
