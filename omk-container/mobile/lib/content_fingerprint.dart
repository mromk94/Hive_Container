import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'url_utils.dart';

class ContentFingerprint {
  ContentFingerprint({
    required this.urlHash,
    required this.titleHash,
    required this.screenshotPhash,
  });

  final String urlHash;
  final String titleHash;
  final String screenshotPhash;

  Map<String, Object?> toJson() => <String, Object?>{
        'url_hash': urlHash,
        'title_hash': titleHash,
        'screenshot_phash': screenshotPhash,
      };
}

String _hashText(String input) {
  final bytes = utf8.encode(input.trim());
  return crypto.sha256.convert(bytes).toString();
}

ContentFingerprint buildFingerprint({
  required String rawUrl,
  required String pageTitle,
  required String screenshotPhash,
}) {
  final canon = canonicalizeUrl(rawUrl);
  final titleHash = _hashText(pageTitle);
  return ContentFingerprint(
    urlHash: canon.hash,
    titleHash: titleHash,
    screenshotPhash: screenshotPhash,
  );
}
