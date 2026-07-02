import 'package:flutter/foundation.dart';

/// Tracks Reddit's OAuth rate limit from `x-ratelimit-*` response headers.
/// Reddit allows 100 requests/minute per OAuth client, windowed in 10-minute
/// buckets (600/window); headers report used/remaining and seconds to reset.
class RateLimitTracker extends ChangeNotifier {
  double used = 0;
  double remaining = 600;
  DateTime resetAt = DateTime.now();
  DateTime lastUpdated = DateTime.fromMillisecondsSinceEpoch(0);

  double get limit => used + remaining;
  bool get hasData => lastUpdated.millisecondsSinceEpoch > 0;

  Duration get untilReset {
    final d = resetAt.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  /// Fraction of the window still available, 0..1.
  double get fractionRemaining {
    if (!hasData || limit == 0) return 1;
    if (untilReset == Duration.zero) return 1; // window rolled over
    return (remaining / limit).clamp(0.0, 1.0);
  }

  void update(Map<String, String> headers) {
    final u = double.tryParse(headers['x-ratelimit-used'] ?? '');
    final r = double.tryParse(headers['x-ratelimit-remaining'] ?? '');
    final s = double.tryParse(headers['x-ratelimit-reset'] ?? '');
    if (u == null || r == null || s == null) return;
    used = u;
    remaining = r;
    resetAt = DateTime.now().add(Duration(seconds: s.round()));
    lastUpdated = DateTime.now();
    notifyListeners();
  }
}
