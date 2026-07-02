/// A Reddit link/post (kind t3).
class Post {
  final String id;
  final String fullname; // t3_<id>
  final String title;
  final String author;
  final String subreddit;
  final double createdUtc;
  final double upvoteRatio;
  final int numComments;
  final String selftext;
  final String url;
  final String domain;
  final String permalink;
  final String? thumbnailUrl;
  final String? previewUrl;
  final bool isSelf;
  final bool over18;
  final bool spoiler;
  final bool stickied;
  final bool locked;
  final bool archived;
  final bool edited;
  final String? linkFlairText;
  final String? removedByCategory;
  final bool isVideo;
  final String? postHint;
  final List<String> galleryUrls;

  // Mutable local state (vote/save reflect optimistic UI updates).
  int score;
  bool? likes; // true = upvoted, false = downvoted, null = no vote
  bool saved;

  Post({
    required this.id,
    required this.fullname,
    required this.title,
    required this.author,
    required this.subreddit,
    required this.createdUtc,
    required this.score,
    required this.upvoteRatio,
    required this.numComments,
    required this.selftext,
    required this.url,
    required this.domain,
    required this.permalink,
    this.thumbnailUrl,
    this.previewUrl,
    required this.isSelf,
    required this.over18,
    required this.spoiler,
    required this.stickied,
    required this.locked,
    required this.archived,
    required this.edited,
    this.linkFlairText,
    this.removedByCategory,
    required this.isVideo,
    this.postHint,
    this.galleryUrls = const [],
    this.likes,
    this.saved = false,
  });

  bool get isRemovedOrDeleted =>
      removedByCategory != null ||
      author == '[deleted]' ||
      (isSelf && (selftext == '[removed]' || selftext == '[deleted]'));

  /// True when the post links to a plain image we can render inline.
  bool get isImage {
    if (postHint == 'image') return true;
    final u = url.toLowerCase();
    return u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.png') ||
        u.endsWith('.gif') ||
        u.endsWith('.webp');
  }

  static String? _cleanThumb(dynamic t) {
    if (t is! String) return null;
    if (t.isEmpty || !t.startsWith('http')) return null; // "self", "default", "nsfw"...
    return t;
  }

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  factory Post.fromJson(Map<String, dynamic> d) {
    String? preview;
    try {
      final images = d['preview']?['images'] as List?;
      if (images != null && images.isNotEmpty) {
        preview = _unescape(images.first['source']['url'] as String);
      }
    } catch (_) {}

    final gallery = <String>[];
    try {
      if (d['is_gallery'] == true && d['media_metadata'] is Map) {
        final items = (d['gallery_data']?['items'] as List?) ?? const [];
        final meta = d['media_metadata'] as Map;
        for (final item in items) {
          final mediaId = item['media_id'];
          final m = meta[mediaId];
          if (m is Map && m['s'] is Map) {
            final src = m['s'] as Map;
            final u = src['u'] ?? src['gif'];
            if (u is String) gallery.add(_unescape(u));
          }
        }
      }
    } catch (_) {}

    return Post(
      id: d['id'] as String,
      fullname: d['name'] as String? ?? 't3_${d['id']}',
      title: _unescape(d['title'] as String? ?? ''),
      author: d['author'] as String? ?? '[deleted]',
      subreddit: d['subreddit'] as String? ?? '',
      createdUtc: (d['created_utc'] as num?)?.toDouble() ?? 0,
      score: (d['score'] as num?)?.toInt() ?? 0,
      upvoteRatio: (d['upvote_ratio'] as num?)?.toDouble() ?? 0,
      numComments: (d['num_comments'] as num?)?.toInt() ?? 0,
      selftext: d['selftext'] as String? ?? '',
      url: _unescape(d['url'] as String? ?? ''),
      domain: d['domain'] as String? ?? '',
      permalink: d['permalink'] as String? ?? '',
      thumbnailUrl: _cleanThumb(d['thumbnail']),
      previewUrl: preview,
      isSelf: d['is_self'] == true,
      over18: d['over_18'] == true,
      spoiler: d['spoiler'] == true,
      stickied: d['stickied'] == true,
      locked: d['locked'] == true,
      archived: d['archived'] == true,
      edited: d['edited'] != false && d['edited'] != null,
      linkFlairText: (d['link_flair_text'] as String?)?.trim(),
      removedByCategory: d['removed_by_category'] as String?,
      isVideo: d['is_video'] == true,
      postHint: d['post_hint'] as String?,
      galleryUrls: gallery,
      likes: d['likes'] as bool?,
      saved: d['saved'] == true,
    );
  }
}
