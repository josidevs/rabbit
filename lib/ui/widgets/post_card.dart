import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../services/tagger.dart';
import '../../utils/format.dart';
import '../../utils/voting.dart';
import 'tag_chip.dart';

/// Apollo-style feed row: metadata line, title, thumbnail on the right,
/// tags, then a stats/action line with score, upvote %, and comments.
class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback onTap;
  final bool showSubreddit;
  final bool enableTags;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.showSubreddit = true,
    this.enableTags = true,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tags = widget.enableTags ? Tagger.tag(post) : const <PostTag>[];
    final metaStyle =
        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          if (widget.showSubreddit)
                            TextSpan(
                              text: 'r/${post.subreddit}',
                              style: metaStyle.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary),
                            ),
                          if (widget.showSubreddit) TextSpan(text: ' · ', style: metaStyle),
                          TextSpan(text: 'u/${post.author}', style: metaStyle),
                          TextSpan(
                              text: ' · ${timeAgo(post.createdUtc)}',
                              style: metaStyle),
                          if (post.stickied)
                            TextSpan(
                                text: ' · pinned',
                                style: metaStyle.copyWith(
                                    color: const Color(0xFF009E73))),
                        ]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontSize: 15, height: 1.25),
                      ),
                      if (post.linkFlairText?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            post.linkFlairText!,
                            style: metaStyle.copyWith(
                                fontStyle: FontStyle.italic, fontSize: 11),
                          ),
                        ),
                      TagRow(tags),
                    ],
                  ),
                ),
                if (post.thumbnailUrl != null) ...[
                  const SizedBox(width: 10),
                  _Thumbnail(post: post),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _VoteButton(
                  up: true,
                  active: post.likes == true,
                  onTap: () => _vote(true),
                ),
                Text(
                  compactCount(post.score),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: post.likes == true
                        ? const Color(0xFFD55E00)
                        : post.likes == false
                            ? const Color(0xFF0072B2)
                            : scheme.onSurfaceVariant,
                  ),
                ),
                _VoteButton(
                  up: false,
                  active: post.likes == false,
                  onTap: () => _vote(false),
                ),
                const SizedBox(width: 10),
                Icon(Icons.how_to_vote_outlined,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text('${(post.upvoteRatio * 100).round()}%', style: metaStyle),
                const SizedBox(width: 10),
                Icon(Icons.mode_comment_outlined,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text(compactCount(post.numComments), style: metaStyle),
                const Spacer(),
                if (!post.isSelf)
                  Flexible(
                    child: Text(
                      post.domain,
                      style: metaStyle.copyWith(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _vote(bool up) {
    castVote(
      context: context,
      fullname: widget.post.fullname,
      current: widget.post.likes,
      up: up,
      apply: (likes, delta) => setState(() {
        widget.post.likes = likes;
        widget.post.score += delta;
      }),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final bool up;
  final bool active;
  final VoidCallback onTap;
  const _VoteButton({required this.up, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final activeColor = up ? const Color(0xFFD55E00) : const Color(0xFF0072B2);
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      icon: Icon(
        up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        size: 18,
        color: active ? activeColor : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final Post post;
  const _Thumbnail({required this.post});

  @override
  Widget build(BuildContext context) {
    final blur = post.over18 || post.spoiler;
    Widget img = CachedNetworkImage(
      imageUrl: post.thumbnailUrl!,
      width: 64,
      height: 64,
      fit: BoxFit.cover,
      errorWidget: (_, _, _) => Container(
        width: 64,
        height: 64,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.link, size: 20),
      ),
    );
    if (blur) {
      img = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: img,
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(6), child: img);
  }
}
