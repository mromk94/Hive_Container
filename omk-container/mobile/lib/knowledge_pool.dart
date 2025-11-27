/// Shared facts & summaries stored in mesh memory.
class KnowledgeItem {
  KnowledgeItem({
    required this.id,
    required this.key,
    required this.summary,
    required this.createdAtMillis,
    required this.sourceTwinId,
  });

  final String id;
  final String key;
  final String summary;
  final int createdAtMillis;
  final String sourceTwinId;
}

class KnowledgePool {
  final List<KnowledgeItem> _items = <KnowledgeItem>[];

  void add(KnowledgeItem item) {
    _items.add(item);
  }

  /// Retrieve items matching a key.
  List<KnowledgeItem> forKey(String key) {
    return _items.where((i) => i.key == key).toList(growable: false);
  }
}
