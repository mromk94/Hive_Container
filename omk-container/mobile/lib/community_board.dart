import 'twin_identity.dart';

/// Micro-community AI board entry for localized updates.
class CommunityPost {
  CommunityPost({
    required this.id,
    required this.originTwinId,
    required this.createdAtMillis,
    required this.kind,
    required this.content,
    this.tags = const <String>[],
  });

  final String id;
  final String originTwinId;
  final int createdAtMillis;
  final String kind; // e.g. 'security', 'tip', 'story'
  final String content;
  final List<String> tags;
}

/// In-memory feed of recent community posts.
class MicroCommunityBoard {
  final List<CommunityPost> _posts = <CommunityPost>[];

  void add(CommunityPost post) {
    _posts.add(post);
  }

  List<CommunityPost> recent({int limit = 50}) {
    final copy = List<CommunityPost>.from(_posts);
    copy.sort((a, b) => b.createdAtMillis.compareTo(a.createdAtMillis));
    if (copy.length > limit) return copy.sublist(0, limit);
    return copy;
  }

  CommunityPost buildLocalPost(TwinIdentity twin, String kind, String content) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'post-$now-${twin.twinId.hashCode & 0xffff}';
    final post = CommunityPost(
      id: id,
      originTwinId: twin.twinId,
      createdAtMillis: now,
      kind: kind,
      content: content,
    );
    add(post);
    return post;
  }
}
