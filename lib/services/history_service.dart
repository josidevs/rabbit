import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_entry.dart';
import '../models/post.dart';

/// Local "recently viewed" store, newest first, capped at [maxEntries].
class HistoryService extends ChangeNotifier {
  static const _key = 'history.entries';
  static const maxEntries = 300;

  final SharedPreferences _prefs;
  List<HistoryEntry> _entries = [];

  HistoryService(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _entries = [
          for (final e in jsonDecode(raw) as List)
            HistoryEntry.fromJson(e as Map<String, dynamic>)
        ];
      } catch (_) {
        _entries = [];
      }
    }
  }

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> recordView(Post post) async {
    _entries.removeWhere((e) => e.postId == post.id);
    _entries.insert(
      0,
      HistoryEntry(
        postId: post.id,
        title: post.title,
        subreddit: post.subreddit,
        author: post.author,
        permalink: post.permalink,
        thumbnailUrl: post.thumbnailUrl,
        viewedAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (_entries.length > maxEntries) {
      _entries = _entries.sublist(0, maxEntries);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String postId) async {
    _entries.removeWhere((e) => e.postId == postId);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _entries = [];
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() => _prefs.setString(
      _key, jsonEncode([for (final e in _entries) e.toJson()]));
}
