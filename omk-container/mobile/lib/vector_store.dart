import 'dart:math';

/// Tiny in-memory vector store using cosine similarity.
class VectorEntry {
  VectorEntry({required this.id, required this.vector});

  final String id; // e.g. url_hash
  final List<double> vector;
}

class VectorStore {
  final List<VectorEntry> _entries = [];

  void upsert(VectorEntry entry) {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      _entries[index] = entry;
    } else {
      _entries.add(entry);
    }
  }

  List<VectorEntry> mostSimilar(List<double> query, {int k = 5}) {
    if (_entries.isEmpty) return const [];
    final scored = <_Scored>[];
    for (final e in _entries) {
      final score = _cosine(query, e.vector);
      scored.add(_Scored(entry: e, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(k).map((e) => e.entry).toList();
  }

  double _cosine(List<double> a, List<double> b) {
    final len = min(a.length, b.length);
    if (len == 0) return 0.0;
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < len; i++) {
      final x = a[i];
      final y = b[i];
      dot += x * y;
      na += x * x;
      nb += y * y;
    }
    if (na == 0 || nb == 0) return 0.0;
    return dot / (sqrt(na) * sqrt(nb));
  }
}

class _Scored {
  _Scored({required this.entry, required this.score});

  final VectorEntry entry;
  final double score;
}
