import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Ordered feature vector for URL risk model.
class UrlRiskFeatures {
  UrlRiskFeatures({
    required this.domainAgeDays,
    required this.certValidDays,
    required this.redirectCount,
    required this.pathEntropy,
    required this.hostEntropy,
    required this.domainEditDistance,
    required this.asnReputationScore,
    required this.pageTextEntropy,
  });

  final double domainAgeDays;
  final double certValidDays;
  final double redirectCount;
  final double pathEntropy;
  final double hostEntropy;
  final double domainEditDistance;
  final double asnReputationScore;
  final double pageTextEntropy;

  Float32List toArray() {
    return Float32List.fromList(<double>[
      domainAgeDays,
      certValidDays,
      redirectCount,
      pathEntropy,
      hostEntropy,
      domainEditDistance,
      asnReputationScore,
      pageTextEntropy,
    ]);
  }
}

enum UrlRiskVerdict { safe, suspect, malicious }

/// Thin wrapper around TFLite model for URL risk.
class UrlRiskModel {
  UrlRiskModel._();

  static final UrlRiskModel instance = UrlRiskModel._();

  Interpreter? _interpreter;
  bool _ready = false;

  bool get isReady => _ready;

  /// Load model from a file path or bundled asset.
  Future<void> load({String? filePath, String assetName = 'assets/models/url_risk.tflite'}) async {
    if (_ready) return;
    try {
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          _interpreter = Interpreter.fromFile(file);
          _ready = true;
          return;
        }
      }
      // Fallback to asset if available.
      _interpreter = await Interpreter.fromAsset(assetName);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Returns risk score in [0, 1], or null if model not ready.
  Future<double?> predict(UrlRiskFeatures features) async {
    if (!_ready || _interpreter == null) return null;
    final input = features.toArray().reshape([1, 8]);
    final output = List.filled(1 * 1, 0.0).reshape([1, 1]);
    _interpreter!.run(input, output);
    final score = output[0][0];
    if (score is double) return score.clamp(0.0, 1.0);
    if (score is num) return score.toDouble().clamp(0.0, 1.0);
    return null;
  }

  /// Classify into SAFE / SUSPECT / MALICIOUS based on thresholds.
  Future<UrlRiskVerdict> classify(UrlRiskFeatures features) async {
    final score = await predict(features);
    if (score == null) return UrlRiskVerdict.suspect;
    if (score >= 0.7) return UrlRiskVerdict.malicious;
    if (score >= 0.3) return UrlRiskVerdict.suspect;
    return UrlRiskVerdict.safe;
  }
}

/// On-device model versioning and rollback management.
class UrlRiskModelStore {
  UrlRiskModelStore._();

  static const _keyVersion = 'url_risk_model_version';
  static const _keyPrevVersion = 'url_risk_model_prev_version';
  static const _keyPath = 'url_risk_model_path';
  static const _keyPrevPath = 'url_risk_model_prev_path';

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static Future<String?> currentPath() async {
    final prefs = await _prefs();
    return prefs.getString(_keyPath);
  }

  static Future<String?> currentVersion() async {
    final prefs = await _prefs();
    return prefs.getString(_keyVersion);
  }

  /// Install a new model from raw bytes.
  ///
  /// - Verifies SHA-256 checksum.
  /// - Writes to a versioned file under app documents dir.
  /// - Performs a lightweight validation by attempting to open with TFLite.
  /// - On success, updates current version and keeps previous for rollback.
  static Future<bool> installModel({
    required Uint8List bytes,
    required String version,
    required String expectedSha256,
  }) async {
    final actual = crypto.sha256.convert(bytes).toString();
    if (actual != expectedSha256) {
      return false;
    }

    final dir = await getApplicationDocumentsDirectory();
    final tmpPath = '${dir.path}/url_risk-$version.tmp.tflite';
    final finalPath = '${dir.path}/url_risk-$version.tflite';

    final tmpFile = File(tmpPath);
    await tmpFile.writeAsBytes(bytes, flush: true);

    // Validate by trying to open an interpreter.
    try {
      final interp = Interpreter.fromFile(tmpFile);
      interp.close();
    } catch (_) {
      await tmpFile.delete().catchError((_) {});
      return false;
    }

    // Move to final path.
    await tmpFile.rename(finalPath);

    final prefs = await _prefs();
    final prevVersion = prefs.getString(_keyVersion);
    final prevPath = prefs.getString(_keyPath);

    await prefs.setString(_keyPrevVersion, prevVersion ?? '');
    if (prevPath != null) {
      await prefs.setString(_keyPrevPath, prevPath);
    }

    await prefs.setString(_keyVersion, version);
    await prefs.setString(_keyPath, finalPath);

    return true;
  }

  /// Roll back to previous model version if available.
  static Future<bool> rollback() async {
    final prefs = await _prefs();
    final prevPath = prefs.getString(_keyPrevPath);
    final prevVersion = prefs.getString(_keyPrevVersion);
    if (prevPath == null || prevVersion == null || prevVersion.isEmpty) {
      return false;
    }

    await prefs.setString(_keyVersion, prevVersion);
    await prefs.setString(_keyPath, prevPath);
    return true;
  }
}
