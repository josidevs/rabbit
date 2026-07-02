import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reddit OAuth2 for a personal "installed app".
///
/// Two modes:
///  * Userless ("installed_client" grant): read-only browsing, no account.
///  * Logged in (authorization-code flow with a loopback redirect):
///    voting, saving, home feed.
///
/// The registered redirect URI on reddit.com/prefs/apps must be exactly
/// [redirectUri].
class AuthService extends ChangeNotifier {
  static const redirectPort = 52377;
  static const redirectUri = 'http://127.0.0.1:$redirectPort/callback';
  static const scopes = 'identity read vote save history mysubreddits';
  static const userAgent = 'rabbit-for-reddit/1.0 (personal use; by /u/rabbit-app-user)';

  static const _kClientId = 'auth.clientId';
  static const _kAccessToken = 'auth.accessToken';
  static const _kRefreshToken = 'auth.refreshToken';
  static const _kExpiresAt = 'auth.expiresAt';
  static const _kUsername = 'auth.username';
  static const _kDeviceId = 'auth.deviceId';

  final SharedPreferences _prefs;

  String? _accessToken;
  String? _refreshToken;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _username;

  AuthService(this._prefs) {
    _accessToken = _prefs.getString(_kAccessToken);
    _refreshToken = _prefs.getString(_kRefreshToken);
    _username = _prefs.getString(_kUsername);
    final exp = _prefs.getInt(_kExpiresAt);
    if (exp != null) _expiresAt = DateTime.fromMillisecondsSinceEpoch(exp);
  }

  String get clientId => _prefs.getString(_kClientId) ?? '';
  bool get hasClientId => clientId.isNotEmpty;
  bool get isLoggedIn => _refreshToken != null;
  String? get username => _username;

  Future<void> setClientId(String id) async {
    await _prefs.setString(_kClientId, id.trim());
    await logout(); // stale tokens belong to the old app registration
    notifyListeners();
  }

  String get _deviceId {
    var id = _prefs.getString(_kDeviceId);
    if (id == null) {
      final rng = Random.secure();
      id = List.generate(26, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[rng.nextInt(36)]).join();
      _prefs.setString(_kDeviceId, id);
    }
    return id;
  }

  /// Returns a valid access token, refreshing or (re-)acquiring as needed.
  Future<String> getAccessToken() async {
    if (!hasClientId) {
      throw AuthException('No Reddit client ID configured. Add one in Settings.');
    }
    if (_accessToken != null && DateTime.now().isBefore(_expiresAt)) {
      return _accessToken!;
    }
    if (_refreshToken != null) {
      await _refresh();
    } else {
      await _acquireUserless();
    }
    return _accessToken!;
  }

  Future<Map<String, dynamic>> _tokenRequest(Map<String, String> body) async {
    final basic = base64Encode(utf8.encode('$clientId:'));
    final resp = await http.post(
      Uri.parse('https://www.reddit.com/api/v1/access_token'),
      headers: {
        'Authorization': 'Basic $basic',
        'User-Agent': userAgent,
      },
      body: body,
    );
    if (resp.statusCode != 200) {
      throw AuthException('Token request failed (HTTP ${resp.statusCode}): ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (json['error'] != null) {
      throw AuthException('Token request failed: ${json['error']}');
    }
    return json;
  }

  Future<void> _storeTokens(Map<String, dynamic> json, {bool keepRefresh = false}) async {
    _accessToken = json['access_token'] as String;
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn - 60));
    if (json['refresh_token'] != null) {
      _refreshToken = json['refresh_token'] as String;
    } else if (!keepRefresh) {
      _refreshToken = null;
    }
    await _prefs.setString(_kAccessToken, _accessToken!);
    await _prefs.setInt(_kExpiresAt, _expiresAt.millisecondsSinceEpoch);
    if (_refreshToken != null) {
      await _prefs.setString(_kRefreshToken, _refreshToken!);
    } else {
      await _prefs.remove(_kRefreshToken);
    }
    notifyListeners();
  }

  Future<void> _acquireUserless() async {
    final json = await _tokenRequest({
      'grant_type': 'https://oauth.reddit.com/grant/installed_client',
      'device_id': _deviceId,
    });
    await _storeTokens(json);
  }

  Future<void> _refresh() async {
    try {
      final json = await _tokenRequest({
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken!,
      });
      await _storeTokens(json, keepRefresh: true);
    } on AuthException {
      // Refresh token revoked/expired — drop to userless so browsing still works.
      await logout();
      await _acquireUserless();
    }
  }

  /// Full login: opens the browser, catches the redirect on a loopback server.
  Future<void> login() async {
    if (!hasClientId) {
      throw AuthException('No Reddit client ID configured. Add one in Settings.');
    }
    final state = Random.secure().nextInt(1 << 31).toRadixString(16);
    final authUrl = Uri.https('www.reddit.com', '/api/v1/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'state': state,
      'redirect_uri': redirectUri,
      'duration': 'permanent',
      'scope': scopes,
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, redirectPort);
    try {
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw AuthException('Could not open browser for login.');
      }
      final request = await server.first.timeout(const Duration(minutes: 5),
          onTimeout: () => throw AuthException('Login timed out.'));
      final params = request.uri.queryParameters;
      final ok = params['code'] != null && params['state'] == state;
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(ok
            ? '<h2>Rabbit is connected. You can close this tab.</h2>'
            : '<h2>Login failed: ${params['error'] ?? 'unknown error'}</h2>');
      await request.response.close();
      if (!ok) {
        throw AuthException('Login failed: ${params['error'] ?? 'state mismatch'}');
      }
      final json = await _tokenRequest({
        'grant_type': 'authorization_code',
        'code': params['code']!,
        'redirect_uri': redirectUri,
      });
      await _storeTokens(json);
      await _fetchUsername();
    } finally {
      await server.close(force: true);
    }
  }

  Future<void> _fetchUsername() async {
    try {
      final resp = await http.get(
        Uri.parse('https://oauth.reddit.com/api/v1/me'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'User-Agent': userAgent,
        },
      );
      if (resp.statusCode == 200) {
        _username = (jsonDecode(resp.body) as Map<String, dynamic>)['name'] as String?;
        if (_username != null) await _prefs.setString(_kUsername, _username!);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _username = null;
    _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
    await _prefs.remove(_kAccessToken);
    await _prefs.remove(_kRefreshToken);
    await _prefs.remove(_kUsername);
    await _prefs.remove(_kExpiresAt);
    notifyListeners();
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
