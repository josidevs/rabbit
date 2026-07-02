import 'package:flutter/material.dart';

import '../../services/tagger.dart';

class TagChip extends StatelessWidget {
  final PostTag tag;
  const TagChip(this.tag, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tag.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tag.icon, size: 12, color: tag.onColor),
          const SizedBox(width: 3),
          Text(
            tag.label,
            style: TextStyle(
              color: tag.onColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class TagRow extends StatelessWidget {
  final List<PostTag> tags;
  const TagRow(this.tags, {super.key});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [for (final t in tags) TagChip(t)],
      ),
    );
  }
}
