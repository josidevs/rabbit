/// A locally stored record of a post the user opened.
class HistoryEntry {
  final String postId;
  final String title;
  final String subreddit;
  final String author;
  final String permalink;
  final String? thumbnailUrl;
  final int viewedAtMillis;

  const HistoryEntry({
    required this.postId,
    required this.title,
    required this.subreddit,
    required this.author,
    required this.permalink,
    this.thumbnailUrl,
    required this.viewedAtMillis,
  });

  String get redditUrl => 'https://www.reddit.com$permalink';

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'title': title,
        'subreddit': subreddit,
        'author': author,
        'permalink': permalink,
        'thumbnailUrl': thumbnailUrl,
        'viewedAtMillis': viewedAtMillis,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> d) => HistoryEntry(
        postId: d['postId'] as String,
        title: d['title'] as String? ?? '',
        subreddit: d['subreddit'] as String? ?? '',
        author: d['author'] as String? ?? '',
        permalink: d['permalink'] as String? ?? '',
        thumbnailUrl: d['thumbnailUrl'] as String?,
        viewedAtMillis: (d['viewedAtMillis'] as num?)?.toInt() ?? 0,
      );
}
