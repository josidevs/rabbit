import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'history_service.dart';
import 'rate_limit.dart';
import 'reddit_api.dart';

/// Simple service locator — this is a single-user personal app, so global
/// singletons initialized once at startup are all we need.
class Services {
  static late final AuthService auth;
  static late final RateLimitTracker rateLimit;
  static late final RedditApi api;
  static late final HistoryService history;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    auth = AuthService(prefs);
    rateLimit = RateLimitTracker();
    api = RedditApi(auth, rateLimit);
    history = HistoryService(prefs);
  }
}
