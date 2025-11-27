import 'security_memory_db.dart';

/// Heuristic planner for what to pre-cache before going offline.
class PredictiveCachePlanner {
  PredictiveCachePlanner(this._db);

  final SecurityMemoryDb _db;

  /// Return a list of url_hashes that are good candidates for
  /// pre-fetching/updating before expected disconnection.
  Future<List<String>> planPreload() async {
    final recent = await _db.listRecent(limit: 100);
    // Simple heuristic: pick the most recent distinct hosts.
    final seen = <String>{};
    final result = <String>[];
    for (final e in recent) {
      if (seen.add(e.host)) {
        result.add(e.urlHash);
      }
      if (result.length >= 10) break;
    }
    return result;
  }
}
