import 'package:flutter/material.dart';

import '../widgets/rate_limit_bar.dart';
import 'feed_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Root scaffold: tab content, then the OAuth rate-limit bar pinned at the
/// bottom above the navigation bar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          FeedScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RateLimitBar(),
          NavigationBar(
            selectedIndex: _tab,
            height: 64,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.view_agenda_outlined),
                selectedIcon: Icon(Icons.view_agenda_rounded),
                label: 'Posts',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_rounded),
                label: 'Recent',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
