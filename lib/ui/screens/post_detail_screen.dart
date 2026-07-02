import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/comment.dart';
import '../../models/post.dart';
import '../../services/reddit_api.dart';
import '../../services/services.dart';
import '../../services/tagger.dart';
import '../../services/wayback_service.dart';
import '../../utils/format.dart';
import '../../utils/voting.dart';
import '../widgets/comment_tile.dart';
import '../widgets/tag_chip.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final Post? initialPost;
  final String? permalinkForArchive; // used when opened from history

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
    this.permalinkForArchive,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  List<CommentNode> _roots = [];
  CommentSort _sort = CommentSort.confidence;
  bool _loading = true;
  String? _error;
  bool _notFound = false;
  final Set<String> _loadingMore = {};

  // Wayback lookup state (only used when the post is deleted/removed).
  bool _checkingArchive = false;
  bool _archiveChecked = false;
  String? _archiveUrl;

  String get _redditUrl {
    final permalink = _post?.permalink ?? widget.permalinkForArchive;
    if (permalink != null && permalink.isNotEmpty) {
      return 'https://www.reddit.com$permalink';
    }
    return 'https://www.reddit.com/comments/${widget.postId}';
  }

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await Services.api.postWithComments(widget.postId, sort: _sort);
      setState(() {
        _post = result.post;
        _roots = result.comments;
        _notFound = false;
      });
      if (result.post.isRemovedOrDeleted) _checkArchive();
    } on RedditApiException catch (e) {
      setState(() {
        if (e.statusCode == 404) {
          _notFound = true;
        } else {
          _error = e.message;
        }
      });
      if (_notFound) _checkArchive();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkArchive() async {
    if (_archiveChecked || _checkingArchive) return;
    setState(() => _checkingArchive = true);
    final url = await WaybackService.findSnapshot(_redditUrl);
    if (mounted) {
      setState(() {
        _archiveUrl = url;
        _archiveChecked = true;
        _checkingArchive = false;
      });
    }
  }

  /// Flattens the tree into visible rows, honoring collapsed subtrees.
  List<CommentNode> get _visible {
    final out = <CommentNode>[];
    void walk(List<CommentNode> nodes) {
      for (final n in nodes) {
        out.add(n);
        if (n is Comment && !n.collapsed) walk(n.replies);
      }
    }

    walk(_roots);
    return out;
  }

  int _descendantCount(Comment c) {
    var n = 0;
    void walk(List<CommentNode> nodes) {
      for (final node in nodes) {
        n++;
        if (node is Comment) walk(node.replies);
      }
    }

    walk(c.replies);
    return n;
  }

  Future<void> _loadMore(MoreStub stub) async {
    final post = _post;
    if (post == null || _loadingMore.contains(stub.id)) return;
    setState(() => _loadingMore.add(stub.id));
    try {
      final nodes = await Services.api.moreChildren(post.fullname, stub);
      setState(() {
        _replaceStub(_roots, stub, nodes);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not load comments: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingMore.remove(stub.id));
    }
  }

  bool _replaceStub(
      List<CommentNode> nodes, MoreStub stub, List<CommentNode> replacement) {
    final i = nodes.indexOf(stub);
    if (i >= 0) {
      nodes.replaceRange(i, i + 1, replacement);
      return true;
    }
    for (final n in nodes) {
      if (n is Comment && _replaceStub(n.replies, stub, replacement)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      appBar: AppBar(
        title: Text(post != null ? 'r/${post.subreddit}' : 'Post'),
        actions: [
          if (post != null) ...[
            IconButton(
              icon: Icon(
                post.saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              ),
              tooltip: post.saved ? 'Unsave' : 'Save',
              onPressed: _toggleSave,
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'browser':
                    launchUrl(Uri.parse(_redditUrl),
                        mode: LaunchMode.externalApplication);
                  case 'copy':
                    await Clipboard.setData(ClipboardData(text: _redditUrl));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied.')));
                    }
                  case 'archive':
                    await _checkArchive();
                    if (_archiveUrl != null) {
                      launchUrl(Uri.parse(_archiveUrl!),
                          mode: LaunchMode.externalApplication);
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('No archived copy found on the Wayback Machine.')));
                    }
                  default:
                    _sort = CommentSort.values.firstWhere((s) => s.api == v);
                    _load();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'browser', child: Text('Open in browser')),
                const PopupMenuItem(value: 'copy', child: Text('Copy link')),
                const PopupMenuItem(
                    value: 'archive', child: Text('Open archived copy')),
                const PopupMenuDivider(),
                for (final s in CommentSort.values)
                  CheckedPopupMenuItem(
                    value: s.api,
                    checked: _sort == s,
                    child: Text('Comments: ${s.label}'),
                  ),
              ],
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_notFound && _post == null) return _DeletedView(state: this);
    if (_error != null && _post == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_post == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final visible = _visible;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visible.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) return _PostHeader(state: this);
          if (i == visible.length + 1) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : visible.isEmpty
                        ? const Text('No comments yet.')
                        : const SizedBox.shrink(),
              ),
            );
          }
          final node = visible[i - 1];
          if (node is Comment) {
            return CommentTile(
              comment: node,
              hiddenCount: node.collapsed ? _descendantCount(node) : 0,
              onToggleCollapse: () =>
                  setState(() => node.collapsed = !node.collapsed),
            );
          }
          final stub = node as MoreStub;
          return MoreTile(
            stub: stub,
            loading: _loadingMore.contains(stub.id),
            onTap: () => _loadMore(stub),
          );
        },
      ),
    );
  }

  Future<void> _toggleSave() async {
    final post = _post!;
    if (!Services.auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log in (Settings tab) to save posts.')));
      return;
    }
    final wasSaved = post.saved;
    setState(() => post.saved = !wasSaved);
    try {
      if (wasSaved) {
        await Services.api.unsave(post.fullname);
      } else {
        await Services.api.save(post.fullname);
      }
    } catch (e) {
      setState(() => post.saved = wasSaved);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }
}

/// Full "post not available" view with the Internet Archive option.
class _DeletedView extends StatelessWidget {
  final _PostDetailScreenState state;
  const _DeletedView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline_rounded, size: 48),
            const SizedBox(height: 12),
            const Text(
              'This post is no longer available on Reddit.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (state._checkingArchive)
              const Column(children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Checking the Internet Archive…'),
              ])
            else if (state._archiveUrl != null)
              FilledButton.icon(
                icon: const Icon(Icons.history_edu_rounded),
                label: const Text('Open archived copy (Wayback Machine)'),
                onPressed: () => launchUrl(Uri.parse(state._archiveUrl!),
                    mode: LaunchMode.externalApplication),
              )
            else if (state._archiveChecked)
              const Text('No archived copy was found on the Wayback Machine.')
            else
              OutlinedButton(
                onPressed: state._checkArchive,
                child: const Text('Check the Internet Archive'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final _PostDetailScreenState state;
  const _PostHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final post = state._post!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metaStyle = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant);
    final tags = Tagger.tag(post);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontSize: 18, height: 1.25)),
              const SizedBox(height: 6),
              Text(
                'u/${post.author} · ${timeAgo(post.createdUtc)}'
                '${post.edited ? ' (edited)' : ''}'
                '${post.isSelf ? '' : ' · ${post.domain}'}',
                style: metaStyle,
              ),
              TagRow(tags),
              if (post.isRemovedOrDeleted)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _RemovedBanner(state: state),
                ),
            ],
          ),
        ),
        if (post.isImage || post.galleryUrls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _PostImages(post: post),
          )
        else if (!post.isSelf)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _LinkCard(post: post),
          ),
        if (post.selftext.isNotEmpty &&
            post.selftext != '[removed]' &&
            post.selftext != '[deleted]')
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: MarkdownBody(
              data: post.selftext,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              onTapLink: (text, href, title) {
                if (href != null) {
                  launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          child: _StatsRow(state: state),
        ),
        Container(height: 6, color: scheme.surfaceContainerHigh),
      ],
    );
  }
}

class _RemovedBanner extends StatelessWidget {
  final _PostDetailScreenState state;
  const _RemovedBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFD55E00).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD55E00)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFD55E00)),
            SizedBox(width: 6),
            Text('This post was removed or deleted.',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          if (state._checkingArchive)
            const Text('Checking the Internet Archive…')
          else if (state._archiveUrl != null)
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              icon: const Icon(Icons.history_edu_rounded, size: 16),
              label: const Text('Open archived copy on the Wayback Machine'),
              onPressed: () => launchUrl(Uri.parse(state._archiveUrl!),
                  mode: LaunchMode.externalApplication),
            )
          else
            const Text('No archived copy found on the Wayback Machine.'),
        ],
      ),
    );
  }
}

class _StatsRow extends StatefulWidget {
  final _PostDetailScreenState state;
  const _StatsRow({required this.state});

  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> {
  @override
  Widget build(BuildContext context) {
    final post = widget.state._post!;
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    return Row(
      children: [
        IconButton(
          onPressed: () => _vote(true),
          icon: Icon(Icons.arrow_upward_rounded,
              color: post.likes == true
                  ? const Color(0xFFD55E00)
                  : scheme.onSurfaceVariant),
        ),
        Text(
          compactCount(post.score),
          style: style.copyWith(fontWeight: FontWeight.w700),
        ),
        IconButton(
          onPressed: () => _vote(false),
          icon: Icon(Icons.arrow_downward_rounded,
              color: post.likes == false
                  ? const Color(0xFF0072B2)
                  : scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
        Icon(Icons.how_to_vote_outlined, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text('${(post.upvoteRatio * 100).round()}% upvoted', style: style),
        const Spacer(),
        Icon(Icons.mode_comment_outlined, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text('${compactCount(post.numComments)} comments', style: style),
      ],
    );
  }

  void _vote(bool up) {
    final post = widget.state._post!;
    castVote(
      context: context,
      fullname: post.fullname,
      current: post.likes,
      up: up,
      apply: (likes, delta) => setState(() {
        post.likes = likes;
        post.score += delta;
      }),
    );
  }
}

class _PostImages extends StatelessWidget {
  final Post post;
  const _PostImages({required this.post});

  @override
  Widget build(BuildContext context) {
    final urls = post.galleryUrls.isNotEmpty
        ? post.galleryUrls
        : [post.previewUrl ?? post.url];
    return Column(
      children: [
        for (final url in urls)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _ImageViewer(url: url, title: post.title))),
              child: _BlurrableImage(
                url: url,
                blur: post.over18 || post.spoiler,
              ),
            ),
          ),
      ],
    );
  }
}

class _BlurrableImage extends StatefulWidget {
  final String url;
  final bool blur;
  const _BlurrableImage({required this.url, required this.blur});

  @override
  State<_BlurrableImage> createState() => _BlurrableImageState();
}

class _BlurrableImageState extends State<_BlurrableImage> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final img = CachedNetworkImage(
      imageUrl: widget.url,
      fit: BoxFit.contain,
      width: double.infinity,
      placeholder: (_, _) => const SizedBox(
          height: 200, child: Center(child: CircularProgressIndicator())),
      errorWidget: (_, _, _) => const SizedBox(
          height: 100, child: Center(child: Icon(Icons.broken_image_outlined))),
    );
    if (!widget.blur || _revealed) return img;
    return GestureDetector(
      onTap: () => setState(() => _revealed = true),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: img,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Sensitive content — tap to reveal',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final Post post;
  const _LinkCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(post.url), mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.link_rounded, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                post.url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.primary, fontSize: 13),
              ),
            ),
            Icon(Icons.open_in_new_rounded,
                size: 16, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final String url;
  final String title;
  const _ImageViewer({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 14)),
      ),
      body: InteractiveViewer(
        maxScale: 6,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: url,
            placeholder: (_, _) => const CircularProgressIndicator(),
            errorWidget: (_, _, _) =>
                const Icon(Icons.broken_image_outlined, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
