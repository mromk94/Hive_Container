import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed security memory store.
///
/// This holds local verdicts and compact context snapshots for URLs/hosts.
class SecurityMemoryEntry {
  SecurityMemoryEntry({
    this.id,
    required this.urlHash,
    required this.host,
    required this.verdict, // e.g. allow | block | review
    required this.riskScore,
    required this.source, // bloom | cache | classifier | escalate
    required this.createdAtMillis,
    required this.expiresAtMillis,
    this.pinned = false,
    this.fingerprintJson,
    this.snapshotJson,
    this.flagsJson,
  });

  final int? id;
  final String urlHash;
  final String host;
  final String verdict;
  final double riskScore;
  final String source;
  final int createdAtMillis;
  final int? expiresAtMillis;
  final bool pinned;
  final String? fingerprintJson;
  final String? snapshotJson;
  final String? flagsJson;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'url_hash': urlHash,
        'host': host,
        'verdict': verdict,
        'risk_score': riskScore,
        'source': source,
        'created_at': createdAtMillis,
        'expires_at': expiresAtMillis,
        'pinned': pinned ? 1 : 0,
        'fingerprint_json': fingerprintJson,
        'snapshot_json': snapshotJson,
        'flags_json': flagsJson,
      };

  static SecurityMemoryEntry fromMap(Map<String, Object?> row) {
    return SecurityMemoryEntry(
      id: row['id'] as int?,
      urlHash: row['url_hash'] as String,
      host: row['host'] as String,
      verdict: row['verdict'] as String,
      riskScore: (row['risk_score'] as num).toDouble(),
      source: row['source'] as String,
      createdAtMillis: row['created_at'] as int,
      expiresAtMillis: row['expires_at'] as int?,
      pinned: (row['pinned'] as int) == 1,
      fingerprintJson: row['fingerprint_json'] as String?,
      snapshotJson: row['snapshot_json'] as String?,
      flagsJson: row['flags_json'] as String?,
    );
  }
}

class SecurityMemoryDb {
  SecurityMemoryDb._(this._db);

  final Database _db;

  static Database? _cached;

  static Future<SecurityMemoryDb> open() async {
    if (_cached != null) {
      return SecurityMemoryDb._(_cached!);
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'omk_security.db');

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE security_memory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  url_hash TEXT NOT NULL,
  host TEXT NOT NULL,
  verdict TEXT NOT NULL,
  risk_score REAL NOT NULL,
  source TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER,
  pinned INTEGER NOT NULL DEFAULT 0,
  fingerprint_json TEXT,
  snapshot_json TEXT,
  flags_json TEXT
);
''');
        await db.execute(
          'CREATE INDEX idx_security_url_hash ON security_memory(url_hash);',
        );
        await db.execute(
          'CREATE INDEX idx_security_host ON security_memory(host);',
        );
        await db.execute(
          'CREATE INDEX idx_security_expires ON security_memory(expires_at);',
        );
        await db.execute(
          'CREATE INDEX idx_security_pinned ON security_memory(pinned);',
        );
      },
    );

    _cached = db;
    return SecurityMemoryDb._(db);
  }

  Future<int> insertOrUpdate(SecurityMemoryEntry entry) async {
    return _db.insert(
      'security_memory',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SecurityMemoryEntry?> getByUrlHash(String urlHash) async {
    final rows = await _db.query(
      'security_memory',
      where: 'url_hash = ?',
      whereArgs: [urlHash],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SecurityMemoryEntry.fromMap(rows.first);
  }

  Future<List<SecurityMemoryEntry>> listRecent({int limit = 50}) async {
    final rows = await _db.query(
      'security_memory',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(SecurityMemoryEntry.fromMap).toList();
  }

  Future<void> setPinned(int id, bool pinned) async {
    await _db.update(
      'security_memory',
      {'pinned': pinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> purgeAll() async {
    await _db.delete('security_memory');
  }

  Future<int> cleanupExpired({int? nowMillis}) async {
    final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
    return _db.delete(
      'security_memory',
      where: 'pinned = 0 AND expires_at IS NOT NULL AND expires_at < ?',
      whereArgs: [now],
    );
  }

  Future<void> deleteById(int id) async {
    await _db.delete('security_memory', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertFromSnapshot({
    required String urlHash,
    required String host,
    required double riskScore,
    required String verdict,
    required String source,
    required Duration ttl,
    Map<String, Object?>? fingerprint,
    Map<String, Object?>? snapshot,
    List<String>? flags,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expires = ttl.inMilliseconds > 0 ? now + ttl.inMilliseconds : null;

    final entry = SecurityMemoryEntry(
      urlHash: urlHash,
      host: host,
      verdict: verdict,
      riskScore: riskScore,
      source: source,
      createdAtMillis: now,
      expiresAtMillis: expires,
      pinned: false,
      fingerprintJson: fingerprint == null ? null : jsonEncode(fingerprint),
      snapshotJson: snapshot == null ? null : jsonEncode(snapshot),
      flagsJson: flags == null ? null : jsonEncode(flags),
    );

    await insertOrUpdate(entry);
  }
}
