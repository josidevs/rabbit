import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: Services.auth,
        builder: (context, _) {
          final auth = Services.auth;
          return ListView(
            children: [
              const _SectionHeader('REDDIT API'),
              ListTile(
                leading: const Icon(Icons.key_rounded),
                title: const Text('Client ID'),
                subtitle: Text(auth.hasClientId
                    ? '${auth.clientId.substring(0, 4)}…  (configured)'
                    : 'Not set — required before anything works'),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: _editClientId,
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Create a Reddit app'),
                subtitle: const Text(
                  'reddit.com/prefs/apps → "create app" → type "installed app" '
                  '→ redirect URI: ${AuthService.redirectUri}',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () => launchUrl(
                  Uri.parse('https://www.reddit.com/prefs/apps'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const Divider(),
              const _SectionHeader('ACCOUNT'),
              if (auth.isLoggedIn)
                ListTile(
                  leading: const Icon(Icons.account_circle_rounded),
                  title: Text('u/${auth.username ?? 'connected'}'),
                  subtitle: const Text('Logged in — voting and saving enabled'),
                  trailing: TextButton(
                    onPressed: () => auth.logout(),
                    child: const Text('Log out'),
                  ),
                )
              else
                ListTile(
                  leading: const Icon(Icons.login_rounded),
                  title: const Text('Log in with Reddit'),
                  subtitle: const Text(
                      'Optional — without it you can browse anonymously, '
                      'but not vote or save.'),
                  trailing: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  enabled: auth.hasClientId && !_busy,
                  onTap: _login,
                ),
              const Divider(),
              const _SectionHeader('ABOUT'),
              const ListTile(
                leading: Icon(Icons.cruelty_free_rounded),
                title: Text('Rabbit for Reddit'),
                subtitle: Text(
                    'Personal-use Reddit client inspired by Apollo.\n'
                    'Heuristic content tags use a colorblind-safe palette with '
                    'icons; the bar at the bottom tracks your OAuth rate limit.'),
                isThreeLine: true,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editClientId() async {
    final controller = TextEditingController(text: Services.auth.clientId);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reddit client ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The short string shown under your app\'s name at '
              'reddit.com/prefs/apps ("installed app" type).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'e.g. AbCdEf123456_789xyz',
              ),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (value != null && value.trim().isNotEmpty) {
      await Services.auth.setClientId(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Client ID saved. Pull the feed to refresh.')));
      }
    }
  }

  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      await Services.auth.login();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Logged in as u/${Services.auth.username ?? '(unknown)'}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Login failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
