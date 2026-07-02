import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/comment.dart';
import '../models/post.dart';
import 'auth_service.dart';
import 'rate_limit.dart';

enum PostSort { hot, newest, top, rising, controversial }

enum TopRange { hour, day, week, month, year, all }

enum CommentSort { confidence, top, newest, controversial, old, qa }

extension PostSortApi on PostSort {
  String get api => switch (this) {
        PostSort.hot => 'hot',
        PostSort.newest => 'new',
        PostSort.top => 'top',
        PostSort.rising => 'rising',
        PostSort.controversial => 'controversial',
      };
  String get label => switch (this) {
        PostSort.hot => 'Hot',
        PostSort.newest => 'New',
        PostSort.top => 'Top',
        PostSort.rising => 'Rising',
        PostSort.controversial => 'Controversial',
      };
}

extension CommentSortApi on CommentSort {
  String get api => switch (this) {
        CommentSort.confidence => 'confidence',
        CommentSort.top => 'top',
        CommentSort.newest => 'new',
        CommentSort.controversial => 'controversial',
        CommentSort.old => 'old',
        CommentSort.qa => 'qa',
      };
  String get label => switch (this) {
        CommentSort.confidence => 'Best',
        CommentSort.top => 'Top',
        CommentSort.newest => 'New',
        CommentSort.controversial => 'Controversial',
        CommentSort.old => 'Old',
        CommentSort.qa => 'Q&A',
      };
}

class FeedPage {
  final List<Post> posts;
  final String? after;
  FeedPage(this.posts, this.after);
}

class PostWithComments {
  final Post post;
  final List<CommentNode> comments;
  PostWithComments(this.post, this.comments);
}

class RedditApiException implements Exception {
  final int statusCode;
  final String message;
  RedditApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class RedditApi {
  static const _base = 'https://oauth.reddit.com';

  final AuthService auth;
  final RateLimitTracker rateLimit;
  final http.Client _client = http.Client();

  RedditApi(this.auth, this.rateLimit);

  Future<Map<String, String>> _headers() async => {
        'Authorization': 'Bearer ${await auth.getAccessToken()}',
        'User-Agent': AuthService.userAgent,
      };

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: {
      'raw_json': '1',
      ...?query,
    });
    final resp = await _client.get(uri, headers: await _headers());
    rateLimit.update(resp.headers);
    if (resp.statusCode == 404) {
      throw RedditApiException(404, 'Not found — the post may have been deleted.');
    }
    if (resp.statusCode == 429) {
      throw RedditApiException(429, 'Rate limited by Reddit. Wait for the bar to reset.');
    }
    if (resp.statusCode != 200) {
      throw RedditApiException(resp.statusCode, 'Reddit API error (HTTP ${resp.statusCode}).');
    }
    return jsonDecode(resp.body);
  }

  Future<void> _post(String path, Map<String, String> body) async {
    final resp = await _client.post(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: body,
    );
    rateLimit.update(resp.headers);
    if (resp.statusCode == 403) {
      throw RedditApiException(403, 'Not allowed — log in with your Reddit account first.');
    }
    if (resp.statusCode != 200) {
      throw RedditApiException(resp.statusCode, 'Reddit API error (HTTP ${resp.statusCode}).');
    }
  }

  /// [subreddit] empty → front page (home when logged in, best-of otherwise).
  /// Use "popular" or "all" for those feeds.
  Future<FeedPage> feed({
    String subreddit = '',
    PostSort sort = PostSort.hot,
    TopRange range = TopRange.day,
    String? after,
    int limit = 25,
  }) async {
    final prefix = subreddit.isEmpty ? '' : '/r/$subreddit';
    final json = await _get('$prefix/${sort.api}', {
      'limit': '$limit',
      'after': ?after,
      if (sort == PostSort.top || sort == PostSort.controversial) 't': range.name,
    }) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    final children = data['children'] as List? ?? const [];
    final posts = <Post>[];
    for (final child in children) {
      if (child['kind'] == 't3') {
        posts.add(Post.fromJson(child['data'] as Map<String, dynamic>));
      }
    }
    return FeedPage(posts, data['after'] as String?);
  }

  Future<FeedPage> search(String query, {String? after}) async {
    final json = await _get('/search', {
      'q': query,
      'limit': '25',
      'after': ?after,
    }) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    final posts = <Post>[
      for (final child in (data['children'] as List? ?? const []))
        if (child['kind'] == 't3') Post.fromJson(child['data'] as Map<String, dynamic>)
    ];
    return FeedPage(posts, data['after'] as String?);
  }

  Future<PostWithComments> postWithComments(
    String postId, {
    CommentSort sort = CommentSort.confidence,
  }) async {
    final json = await _get('/comments/$postId', {
      'sort': sort.api,
      'limit': '150',
      'depth': '10',
    }) as List;
    final postData =
        json[0]['data']['children'][0]['data'] as Map<String, dynamic>;
    final post = Post.fromJson(postData);
    final commentChildren = json[1]['data']['children'] as List? ?? const [];
    final comments = <CommentNode>[];
    for (final child in commentChildren) {
      final node = parseCommentNode(child as Map<String, dynamic>, 0);
      if (node != null) comments.add(node);
    }
    return PostWithComments(post, comments);
  }

  /// Resolves a "more comments" stub into real nodes.
  Future<List<CommentNode>> moreChildren(String linkFullname, MoreStub stub) async {
    final json = await _get('/api/morechildren', {
      'api_type': 'json',
      'link_id': linkFullname,
      'children': stub.childIds.take(100).join(','),
      'sort': 'confidence',
    }) as Map<String, dynamic>;
    final things = json['json']?['data']?['things'] as List? ?? const [];

    // morechildren returns a flat list; rebuild depth from parent links.
    final depthByFullname = <String, int>{stub.parentFullname: stub.depth - 1};
    final nodes = <CommentNode>[];
    final nodeByFullname = <String, Comment>{};
    for (final thing in things) {
      final kind = thing['kind'];
      final data = thing['data'] as Map<String, dynamic>?;
      if (data == null) continue;
      final parent = data['parent_id'] as String? ?? '';
      final depth = (depthByFullname[parent] ?? stub.depth - 1) + 1;
      if (kind == 't1') {
        final c = Comment.fromJson(data, depth);
        depthByFullname[c.fullname] = depth;
        nodeByFullname[c.fullname] = c;
        final parentNode = nodeByFullname[parent];
        if (parentNode != null) {
          parentNode.replies.add(c);
        } else {
          nodes.add(c);
        }
      } else if (kind == 'more') {
        final m = MoreStub.fromJson(data, depth);
        if (m.childIds.isEmpty && m.count == 0) continue;
        final parentNode = nodeByFullname[parent];
        if (parentNode != null) {
          parentNode.replies.add(m);
        } else {
          nodes.add(m);
        }
      }
    }
    return nodes;
  }

  /// [dir]: 1 upvote, -1 downvote, 0 clear.
  Future<void> vote(String fullname, int dir) =>
      _post('/api/vote', {'id': fullname, 'dir': '$dir'});

  Future<void> save(String fullname) => _post('/api/save', {'id': fullname});

  Future<void> unsave(String fullname) => _post('/api/unsave', {'id': fullname});

  Future<List<String>> mySubreddits() async {
    final names = <String>[];
    String? after;
    for (var i = 0; i < 4; i++) {
      final json = await _get('/subreddits/mine/subscriber', {
        'limit': '100',
        'after': ?after,
      }) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      for (final child in (data['children'] as List? ?? const [])) {
        final name = child['data']?['display_name'];
        if (name is String) names.add(name);
      }
      after = data['after'] as String?;
      if (after == null) break;
    }
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }
}
