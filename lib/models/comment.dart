/// A node in a comment tree: either a real comment or a "load more" stub.
abstract class CommentNode {
  int get depth;
}

class Comment implements CommentNode {
  final String id;
  final String fullname; // t1_<id>
  final String author;
  final String body;
  final double createdUtc;
  final bool scoreHidden;
  final bool isSubmitter;
  final bool stickied;
  final String? distinguished; // "moderator", "admin"
  final String? flairText;
  final bool edited;
  @override
  final int depth;
  final List<CommentNode> replies;

  int score;
  bool? likes;
  bool saved;
  bool collapsed;

  Comment({
    required this.id,
    required this.fullname,
    required this.author,
    required this.body,
    required this.createdUtc,
    required this.scoreHidden,
    required this.isSubmitter,
    required this.stickied,
    this.distinguished,
    this.flairText,
    required this.edited,
    required this.depth,
    required this.replies,
    required this.score,
    this.likes,
    this.saved = false,
    this.collapsed = false,
  });

  factory Comment.fromJson(Map<String, dynamic> d, int depth) {
    final replies = <CommentNode>[];
    final r = d['replies'];
    if (r is Map<String, dynamic>) {
      final children = r['data']?['children'] as List? ?? const [];
      for (final child in children) {
        final node = parseCommentNode(child as Map<String, dynamic>, depth + 1);
        if (node != null) replies.add(node);
      }
    }
    return Comment(
      id: d['id'] as String,
      fullname: d['name'] as String? ?? 't1_${d['id']}',
      author: d['author'] as String? ?? '[deleted]',
      body: d['body'] as String? ?? '',
      createdUtc: (d['created_utc'] as num?)?.toDouble() ?? 0,
      score: (d['score'] as num?)?.toInt() ?? 0,
      scoreHidden: d['score_hidden'] == true,
      isSubmitter: d['is_submitter'] == true,
      stickied: d['stickied'] == true,
      distinguished: d['distinguished'] as String?,
      flairText: (d['author_flair_text'] as String?)?.trim(),
      edited: d['edited'] != false && d['edited'] != null,
      depth: depth,
      replies: replies,
      likes: d['likes'] as bool?,
      saved: d['saved'] == true,
    );
  }
}

/// "Load more comments" stub (kind "more").
class MoreStub implements CommentNode {
  final String id;
  final String parentFullname;
  final int count;
  final List<String> childIds;
  @override
  final int depth;

  MoreStub({
    required this.id,
    required this.parentFullname,
    required this.count,
    required this.childIds,
    required this.depth,
  });

  factory MoreStub.fromJson(Map<String, dynamic> d, int depth) => MoreStub(
        id: d['id'] as String,
        parentFullname: d['parent_id'] as String? ?? '',
        count: (d['count'] as num?)?.toInt() ?? 0,
        childIds: (d['children'] as List? ?? const []).cast<String>(),
        depth: depth,
      );
}

CommentNode? parseCommentNode(Map<String, dynamic> wrapped, int depth) {
  final kind = wrapped['kind'];
  final data = wrapped['data'] as Map<String, dynamic>?;
  if (data == null) return null;
  if (kind == 't1') return Comment.fromJson(data, depth);
  if (kind == 'more') {
    final stub = MoreStub.fromJson(data, depth);
    // "more" with no children and count 0 is a "continue this thread" link.
    if (stub.childIds.isEmpty && stub.count == 0) return null;
    return stub;
  }
  return null;
}
