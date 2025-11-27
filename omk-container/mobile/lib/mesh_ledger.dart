import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// Append-only local ledger entry for mesh interactions.
class MeshLedgerEntry {
  MeshLedgerEntry({
    required this.id,
    required this.prevHash,
    required this.payload,
    required this.createdAtMillis,
  });

  final String id;
  final String prevHash;
  final Map<String, Object?> payload;
  final int createdAtMillis;

  String computeHash() {
    final data = <String, Object?>{
      'id': id,
      'prev': prevHash,
      'payload': payload,
      'ts': createdAtMillis,
    };
    final jsonStr = jsonEncode(data);
    return crypto.sha256.convert(utf8.encode(jsonStr)).toString();
  }
}
