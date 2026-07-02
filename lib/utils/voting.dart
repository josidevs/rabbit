import 'package:flutter/material.dart';

import '../services/reddit_api.dart';
import '../services/services.dart';

/// Optimistically applies a vote and calls the API; rolls back and shows a
/// snackbar on failure. Returns the score delta applied.
Future<void> castVote({
  required BuildContext context,
  required String fullname,
  required bool? current, // true=up, false=down, null=none
  required bool up, // which arrow was tapped
  required void Function(bool? likes, int scoreDelta) apply,
}) async {
  if (!Services.auth.isLoggedIn) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log in (Settings tab) to vote.')),
    );
    return;
  }

  final bool? next;
  final int dir;
  if (up) {
    next = current == true ? null : true;
    dir = current == true ? 0 : 1;
  } else {
    next = current == false ? null : false;
    dir = current == false ? 0 : -1;
  }
  int delta(bool? from, bool? to) =>
      (to == true ? 1 : to == false ? -1 : 0) -
      (from == true ? 1 : from == false ? -1 : 0);

  final d = delta(current, next);
  apply(next, d);
  try {
    await Services.api.vote(fullname, dir);
  } on Exception catch (e) {
    apply(current, -d); // roll back
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is RedditApiException ? e.message : 'Vote failed: $e')),
      );
    }
  }
}
