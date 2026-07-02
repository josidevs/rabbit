import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rabbit/main.dart';
import 'package:rabbit/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots to feed, tabs and rate-limit bar render',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Services.init();

    await tester.pumpWidget(const RabbitApp());
    await tester.pump();

    // No client ID configured -> feed shows the setup message.
    expect(find.textContaining('No Reddit API client ID'), findsOneWidget);

    // Rate-limit bar is pinned at the bottom.
    expect(find.textContaining('API rate limit'), findsOneWidget);

    // Bottom navigation works.
    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();
    expect(find.text('Recently Viewed'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Client ID'), findsOneWidget);
    expect(find.textContaining('Not set'), findsOneWidget);

    // History starts empty.
    expect(Services.history.entries, isEmpty);

    // NavigationBar + rate limit bar coexist in the shell.
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
