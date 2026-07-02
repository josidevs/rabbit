import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/comment.dart';
import '../../utils/format.dart';
import '../../utils/voting.dart';

/// Apollo-style depth rail colors (Okabe–Ito, colorblind-safe).
const commentRailColors = [
  Color(0xFFD55E00),
  Color(0xFFE69F00),
  Color(0xFF009E73),
  Color(0xFF56B4E9),
  Color(0xFF0072B2),
  Color(0xFFCC79A7),
  Color(0xFFF0E442),
];

class CommentTile extends StatelessWidget {
  final Comment comment;
  final VoidCallback onToggleCollapse;
  final int hiddenCount;

  const CommentTile({
    super.key,
    required this.comment,
    required this.onToggleCollapse,
    this.hiddenCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metaStyle = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final authorColor = comment.isSubmitter
        ? const Color(0xFF0072B2)
        : comment.distinguished == 'moderator'
            ? const Color(0xFF009E73)
            : comment.distinguished == 'admin'
                ? const Color(0xFFD55E00)
                : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onToggleCollapse,
      child: _DepthRail(
        depth: comment.depth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'u/${comment.author}'
                      '${comment.isSubmitter ? ' (OP)' : ''}'
                      '${comment.distinguished != null ? ' [${comment.distinguished}]' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: metaStyle.copyWith(
                          fontWeight: FontWeight.w600, color: authorColor),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    comment.likes == false
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 12,
                    color: comment.likes == true
                        ? const Color(0xFFD55E00)
                        : comment.likes == false
                            ? const Color(0xFF0072B2)
                            : scheme.onSurfaceVariant,
                  ),
                  Text(
                    comment.scoreHidden ? '—' : compactCount(comment.score),
                    style: metaStyle,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${timeAgo(comment.createdUtc)}${comment.edited ? '*' : ''}',
                    style: metaStyle,
                  ),
                  const Spacer(),
                  if (comment.collapsed && hiddenCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('+$hiddenCount', style: metaStyle),
                    ),
                ],
              ),
              if (!comment.collapsed) ...[
                const SizedBox(height: 2),
                MarkdownBody(
                  data: comment.body,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                    blockquoteDecoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                      border: Border(
                        left: BorderSide(color: scheme.primary, width: 3),
                      ),
                    ),
                  ),
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      launchUrl(Uri.parse(href),
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                _ActionRow(comment: comment),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  final Comment comment;
  const _ActionRow({required this.comment});

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _MiniButton(
          icon: Icons.arrow_upward_rounded,
          color: c.likes == true ? const Color(0xFFD55E00) : scheme.onSurfaceVariant,
          onTap: () => _vote(true),
        ),
        _MiniButton(
          icon: Icons.arrow_downward_rounded,
          color: c.likes == false ? const Color(0xFF0072B2) : scheme.onSurfaceVariant,
          onTap: () => _vote(false),
        ),
      ],
    );
  }

  void _vote(bool up) {
    castVote(
      context: context,
      fullname: widget.comment.fullname,
      current: widget.comment.likes,
      up: up,
      apply: (likes, delta) => setState(() {
        widget.comment.likes = likes;
        widget.comment.score += delta;
      }),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MiniButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

/// "Load more comments" row.
class MoreTile extends StatelessWidget {
  final MoreStub stub;
  final bool loading;
  final VoidCallback onTap;

  const MoreTile({
    super.key,
    required this.stub,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: loading ? null : onTap,
      child: _DepthRail(
        depth: stub.depth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.unfold_more_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                loading
                    ? 'Loading…'
                    : 'Load ${stub.count} more ${stub.count == 1 ? 'comment' : 'comments'}',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DepthRail extends StatelessWidget {
  final int depth;
  final Widget child;
  const _DepthRail({required this.depth, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: 10.0 * depth),
      child: Container(
        decoration: depth > 0
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: commentRailColors[(depth - 1) % commentRailColors.length],
                    width: 2.5,
                  ),
                ),
              )
            : BoxDecoration(
                border: Border(
                  top: BorderSide(color: scheme.outlineVariant, width: 0.5),
                ),
              ),
        child: child,
      ),
    );
  }
}
