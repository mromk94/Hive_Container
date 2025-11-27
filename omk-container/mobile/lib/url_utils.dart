import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// Canonicalize a URL for use in the memory loop.
class CanonicalUrl {
  CanonicalUrl({required this.url, required this.host, required this.hash});

  final Uri url;
  final String host;
  final String hash; // sha256 of canonical string
}

CanonicalUrl canonicalizeUrl(String raw) {
  Uri uri;
  try {
    uri = Uri.parse(raw.trim());
  } catch (_) {
    uri = Uri();
  }

  var scheme = uri.scheme.isEmpty ? 'https' : uri.scheme.toLowerCase();
  var host = uri.host.toLowerCase();

  // Strip common tracking params
  final keepQuery = <String, String>{};
  uri.queryParameters.forEach((k, v) {
    final key = k.toLowerCase();
    if (key.startsWith('utm_') ||
        key == 'gclid' ||
        key == 'fbclid' ||
        key == 'ref_src') return;
    keepQuery[k] = v;
  });

  var path = uri.path;
  if (path.isEmpty) path = '/';
  if (path != '/' && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }

  final canon = Uri(
    scheme: scheme,
    host: host,
    port: uri.hasPort ? uri.port : null,
    path: path,
    queryParameters: keepQuery.isEmpty ? null : keepQuery,
  );

  final bytes = utf8.encode(canon.toString());
  final digest = crypto.sha256.convert(bytes).toString();

  return CanonicalUrl(url: canon, host: host, hash: digest);
}
