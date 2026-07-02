/// Apollo-style compact formatting helpers.
library;

/// 12345 -> "12.3k", 1234567 -> "1.2m"
String compactCount(int n) {
  final abs = n.abs();
  final sign = n < 0 ? '-' : '';
  if (abs >= 1000000) {
    return '$sign${_trim((abs / 1000000).toStringAsFixed(1))}m';
  }
  if (abs >= 10000) return '$sign${(abs / 1000).round()}k';
  if (abs >= 1000) return '$sign${_trim((abs / 1000).toStringAsFixed(1))}k';
  return '$n';
}

String _trim(String s) => s.endsWith('.0') ? s.substring(0, s.length - 2) : s;

/// Seconds-since-epoch -> "5m", "3h", "2d", "4mo", "1y"
String timeAgo(double createdUtc) {
  final created =
      DateTime.fromMillisecondsSinceEpoch((createdUtc * 1000).round());
  final diff = DateTime.now().difference(created);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 30) return '${diff.inDays}d';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}mo';
  return '${diff.inDays ~/ 365}y';
}

/// Millis-since-epoch -> "Today 14:05", "Mon 09:12", "2026-05-01"
String viewedAt(int millis) {
  final t = DateTime.fromMillisecondsSinceEpoch(millis);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (day == today) return 'Today $hm';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday $hm';
  if (now.difference(t).inDays < 7) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${names[t.weekday - 1]} $hm';
  }
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
