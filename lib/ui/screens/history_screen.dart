import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/history_entry.dart';
import '../../services/services.dart';
import '../../services/wayback_service.dart';
import '../../utils/format.dart';
import 'post_detail_screen.dart';

/// Recently viewed posts. Opening an entry re-fetches the post; if it is
/// deleted, the detail screen offers the Internet Archive copy when one
/// exists. Each row also has a direct Wayback lookup.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Viewed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear history',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear history?'),
                  content: const Text(
                      'This removes all recently viewed posts from this device.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear')),
                  ],
                ),
              );
              if (confirm == true) Services.history.clear();
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Services.history,
        builder: (context, _) {
          final entries = Services.history.entries;
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Posts you open will show up here — including a route back '
                  'to them via the Internet Archive if they get deleted.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 0.5, thickness: 0.5),
            itemBuilder: (context, i) => _HistoryTile(entry: entries[i]),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(entry.postId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: const Color(0xFFD55E00),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => Services.history.remove(entry.postId),
      child: ListTile(
        leading: entry.thumbnailUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: entry.thumbnailUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      const Icon(Icons.article_outlined),
                ),
              )
            : const Icon(Icons.article_outlined),
        title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'r/${entry.subreddit} · u/${entry.author} · viewed ${viewedAt(entry.viewedAtMillis)}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _onMenu(context, v),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'reddit', child: Text('Open on Reddit')),
            PopupMenuItem(
                value: 'wayback', child: Text('Find on Internet Archive')),
            PopupMenuItem(value: 'remove', child: Text('Remove from history')),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(
              postId: entry.postId,
              permalinkForArchive: entry.permalink,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, String action) async {
    switch (action) {
      case 'reddit':
        launchUrl(Uri.parse(entry.redditUrl),
            mode: LaunchMode.externalApplication);
      case 'remove':
        Services.history.remove(entry.postId);
      case 'wayback':
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
            const SnackBar(content: Text('Checking the Internet Archive…')));
        final url = await WaybackService.findSnapshot(entry.redditUrl);
        messenger.hideCurrentSnackBar();
        if (url != null) {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          messenger.showSnackBar(const SnackBar(
              content: Text('No archived copy found on the Wayback Machine.')));
        }
    }
  }
}
