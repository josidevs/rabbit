import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../services/reddit_api.dart';
import '../../services/services.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scroll = ScrollController();
  final List<Post> _posts = [];

  String _subreddit = ''; // '' = front page
  PostSort _sort = PostSort.hot;
  TopRange _range = TopRange.day;
  String? _after;
  bool _loading = false;
  bool _exhausted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - 900) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (!reset && _exhausted) return;
    if (!Services.auth.hasClientId) {
      setState(() => _error = 'no-client-id');
      return;
    }
    setState(() {
      _loading = true;
      if (reset) {
        _error = null;
        _exhausted = false;
      }
    });
    try {
      final page = await Services.api.feed(
        subreddit: _subreddit,
        sort: _sort,
        range: _range,
        after: reset ? null : _after,
      );
      setState(() {
        if (reset) _posts.clear();
        _posts.addAll(page.posts);
        _after = page.after;
        _exhausted = page.after == null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _title => _subreddit.isEmpty
      ? (Services.auth.isLoggedIn ? 'Home' : 'Front Page')
      : 'r/$_subreddit';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _pickSubreddit,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(_title, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search posts',
            onPressed: _search,
          ),
          PopupMenuButton<Object>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort: ${_sort.label}',
            onSelected: (v) {
              setState(() {
                if (v is PostSort) _sort = v;
                if (v is TopRange) {
                  _sort = PostSort.top;
                  _range = v;
                }
              });
              _load(reset: true);
            },
            itemBuilder: (context) => [
              for (final s in PostSort.values)
                CheckedPopupMenuItem(
                  value: s,
                  checked: _sort == s,
                  child: Text(s.label),
                ),
              const PopupMenuDivider(),
              for (final r in TopRange.values)
                CheckedPopupMenuItem(
                  value: r,
                  checked: _sort == PostSort.top && _range == r,
                  child: Text('Top · ${r.name}'),
                ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error == 'no-client-id') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.key_off_rounded, size: 48),
              const SizedBox(height: 12),
              const Text(
                'No Reddit API client ID configured yet.\n\n'
                'Go to the Settings tab, follow the steps to create a free '
                '"installed app" at reddit.com/prefs/apps, and paste its '
                'client ID.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _load(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null && _posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _load(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_posts.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _posts.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 0.5, thickness: 0.5),
        itemBuilder: (context, i) {
          if (i == _posts.length) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: _exhausted
                    ? const Text("That's everything.")
                    : const CircularProgressIndicator(),
              ),
            );
          }
          final post = _posts[i];
          return PostCard(
            post: post,
            onTap: () => _openPost(post),
          );
        },
      ),
    );
  }

  void _openPost(Post post) {
    Services.history.recordView(post);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: post.id, initialPost: post),
      ),
    );
  }

  Future<void> _pickSubreddit() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SubredditPicker(current: _subreddit),
    );
    if (result != null) {
      setState(() => _subreddit = result);
      _load(reset: true);
      _scroll.jumpTo(0);
    }
  }

  Future<void> _search() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Reddit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search posts…'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    if (query == null || query.trim().isEmpty || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _SearchResultsScreen(query: query.trim())),
    );
  }
}

class _SubredditPicker extends StatefulWidget {
  final String current;
  const _SubredditPicker({required this.current});

  @override
  State<_SubredditPicker> createState() => _SubredditPickerState();
}

class _SubredditPickerState extends State<_SubredditPicker> {
  final _controller = TextEditingController();
  List<String>? _subscriptions;
  bool _loadingSubs = false;

  static const _builtin = [
    ('Front Page', ''),
    ('Popular', 'popular'),
    ('All', 'all'),
  ];

  @override
  void initState() {
    super.initState();
    if (Services.auth.isLoggedIn) {
      _loadingSubs = true;
      Services.api.mySubreddits().then((subs) {
        if (mounted) setState(() => _subscriptions = subs);
      }).catchError((_) {}).whenComplete(() {
        if (mounted) setState(() => _loadingSubs = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _controller,
              autofocus: false,
              decoration: const InputDecoration(
                prefixText: 'r/',
                hintText: 'go to subreddit…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (v) =>
                  Navigator.pop(context, v.trim().replaceFirst(RegExp('^/?r/'), '')),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                for (final (label, value) in _builtin)
                  ListTile(
                    leading: Icon(value == ''
                        ? Icons.home_outlined
                        : value == 'popular'
                            ? Icons.trending_up_rounded
                            : Icons.public_rounded),
                    title: Text(label),
                    selected: widget.current == value,
                    onTap: () => Navigator.pop(context, value),
                  ),
                if (_loadingSubs)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_subscriptions != null && _subscriptions!.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('SUBSCRIPTIONS',
                        style: TextStyle(fontSize: 11, letterSpacing: 1)),
                  ),
                  for (final s in _subscriptions!)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.tag_rounded, size: 18),
                      title: Text('r/$s'),
                      selected: widget.current == s,
                      onTap: () => Navigator.pop(context, s),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsScreen extends StatefulWidget {
  final String query;
  const _SearchResultsScreen({required this.query});

  @override
  State<_SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<_SearchResultsScreen> {
  final List<Post> _posts = [];
  String? _after;
  bool _loading = true;
  bool _exhausted = false;
  String? _error;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 900) {
        _load();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_exhausted || (_loading && _posts.isNotEmpty)) return;
    setState(() => _loading = true);
    try {
      final page = await Services.api.search(widget.query, after: _after);
      setState(() {
        _posts.addAll(page.posts);
        _after = page.after;
        _exhausted = page.after == null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('“${widget.query}”')),
      body: _error != null
          ? Center(child: Text(_error!))
          : _posts.isEmpty && _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  controller: _scroll,
                  itemCount: _posts.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 0.5, thickness: 0.5),
                  itemBuilder: (context, i) {
                    final post = _posts[i];
                    return PostCard(
                      post: post,
                      onTap: () {
                        Services.history.recordView(post);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(
                                postId: post.id, initialPost: post),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
