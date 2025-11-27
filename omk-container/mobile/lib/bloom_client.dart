import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';

/// Simple Bloom filter client for host membership checks.
class BloomFilter {
  BloomFilter({required this.bits, required this.k, required this.version});

  final Uint8List bits;
  final int k;
  final String version;

  bool contains(String value) {
    if (bits.isEmpty || k <= 0) return false;
    final digest = crypto.sha256.convert(value.codeUnits).bytes;
    final m = bits.length * 8;
    for (var i = 0; i < k; i++) {
      final idx = _hash(digest, i, m);
      final byteIndex = idx >> 3;
      final bitMask = 1 << (idx & 7);
      if ((bits[byteIndex] & bitMask) == 0) return false;
    }
    return true; // may be false positive
  }

  int _hash(List<int> digest, int i, int m) {
    final a = digest[i % digest.length];
    final b = digest[(i * 7) % digest.length];
    final combined = (a << 8) ^ b ^ (i * 31);
    return (combined.abs()) % m;
  }
}

class BloomClient {
  BloomClient(this._dio, {this.baseUrl = 'http://10.0.2.2:4317'});

  final Dio _dio;
  final String baseUrl;

  BloomFilter? _filter;

  String? get currentVersion => _filter?.version;

  Future<void> sync() async {
    final res = await _dio.post('$baseUrl/sync-bloom', data: {
      'lastVersion': currentVersion,
    });
    final data = res.data as Map<String, dynamic>;
    final changed = data['changed'] == true;
    if (!changed) return;
    final bloom = data['bloom'] as Map<String, dynamic>?;
    if (bloom == null) return;

    // Real implementation would reconstruct bitset from bloom['chunks'].
    // For now, create an empty filter with metadata only.
    final version = bloom['version'] as String? ?? 'unknown';
    final estEntries = (bloom['estimatedEntries'] as num?)?.toInt() ?? 0;
    final fpRate = (bloom['falsePositiveRate'] as num?)?.toDouble() ?? 0.01;

    if (estEntries <= 0) {
      _filter = BloomFilter(bits: Uint8List(0), k: 0, version: version);
      return;
    }

    final m = _optimalM(estEntries, fpRate);
    final k = _optimalK(estEntries, m);
    _filter = BloomFilter(bits: Uint8List((m + 7) ~/ 8), k: k, version: version);
  }

  bool mayContainHost(String host) {
    final f = _filter;
    if (f == null) return false;
    return f.contains(host.toLowerCase());
  }

  int _optimalM(int n, double p) {
    // m = - (n * ln p) / (ln 2)^2
    final ln2 = log(2);
    return max(1, (-n * log(p) / (ln2 * ln2)).round());
  }

  int _optimalK(int n, int m) {
    // k = (m/n) * ln 2
    if (n <= 0) return 1;
    return max(1, ((m / n) * log(2)).round());
  }
}
