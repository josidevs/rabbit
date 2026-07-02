import 'dart:convert';

import 'package:http/http.dart' as http;

/// Looks up archived copies of Reddit posts on the Internet Archive's
/// Wayback Machine.
class WaybackService {
  /// Returns the URL of the closest archived snapshot, or null if the page
  /// was never archived (or the availability API failed).
  static Future<String?> findSnapshot(String redditUrl) async {
    try {
      final uri = Uri.https('archive.org', '/wayback/available', {
        'url': redditUrl,
      });
      final resp = await http
          .get(uri, headers: {'User-Agent': 'rabbit-for-reddit/1.0 (personal use)'})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final closest = json['archived_snapshots']?['closest'];
      if (closest is Map && closest['available'] == true) {
        final url = closest['url'];
        if (url is String && url.isNotEmpty) {
          // Prefer https — the API often returns http.
          return url.replaceFirst(RegExp('^http://'), 'https://');
        }
      }
    } catch (_) {}
    return null;
  }
}
