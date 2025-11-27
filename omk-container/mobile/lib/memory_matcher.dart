import 'dart:convert';

import 'security_memory_db.dart';

class MemoryMatchResult {
  MemoryMatchResult({required this.entry, required this.similarity});

  final SecurityMemoryEntry entry;
  final double similarity;
}

/// Fuzzy matcher to avoid redundant AI calls for very similar contexts.
class MemoryMatcher {
  static Future<MemoryMatchResult?> findSimilar({
    required String urlHash,
    required String host,
    required List<String> textSnippets,
    double threshold = 0.8,
  }) async {
    if (textSnippets.isEmpty) return null;
    final targetTokens = _tokens(textSnippets);
    if (targetTokens.isEmpty) return null;

    final db = await SecurityMemoryDb.open();
    final recent = await db.listRecent(limit: 200);

    MemoryMatchResult? best;

    for (final e in recent) {
      if (e.urlHash == urlHash) continue; // exact match handled elsewhere
      if (e.host != host) continue; // keep comparison local to the same host
      final snapJson = e.snapshotJson;
      if (snapJson == null || snapJson.isEmpty) continue;
      Map<String, dynamic> snap;
      try {
        snap = jsonDecode(snapJson) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final rawSnips = snap['top_text_snippets'];
      if (rawSnips is! List) continue;
      final otherTokens = _tokens(rawSnips.map((e) => e.toString()).toList());
      if (otherTokens.isEmpty) continue;
      final score = _jaccard(targetTokens, otherTokens);
      if (score >= threshold && (best == null || score > best.similarity)) {
        best = MemoryMatchResult(entry: e, similarity: score);
      }
    }

    return best;
  }

  static Set<String> _tokens(List<String> texts) {
    final out = <String>{};
    for (final t in texts) {
      final lower = t.toLowerCase();
      final parts = lower.split(RegExp(r'[^a-z0-9]+'));
      for (final p in parts) {
        if (p.length < 3) continue;
        out.add(p);
      }
    }
    return out;
  }

  static double _jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final intersection = a.intersection(b).length.toDouble();
    final union = a.union(b).length.toDouble();
    return union == 0 ? 0.0 : intersection / union;
  }
}
