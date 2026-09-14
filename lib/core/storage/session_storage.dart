import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  static const _kUser = 'session_user';

  // The sign-in credentials, kept so an expired Odoo session can be renewed
  // without throwing the user back to the login screen mid-visit. Odoo's
  // `/web/session/authenticate` is the only way to mint a new `session_id` for
  // these routes (there is no refresh token), so this is what "re-authenticate
  // and retry once" in docs/API.md requires. Stored only in the platform
  // keystore/keychain via FlutterSecureStorage, never in SharedPreferences,
  // and wiped by [clear] on every logout.
  static const _kLogin = 'session_login';
  static const _kPassword = 'session_password';

  final FlutterSecureStorage _storage;

  SessionStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: _kUser, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: _kUser);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCredentials({
    required String login,
    required String password,
  }) async {
    await _storage.write(key: _kLogin, value: login);
    await _storage.write(key: _kPassword, value: password);
  }

  Future<({String login, String password})?> readCredentials() async {
    final login = await _storage.read(key: _kLogin);
    final password = await _storage.read(key: _kPassword);
    if (login == null || login.isEmpty || password == null) return null;
    return (login: login, password: password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kUser);
    await _storage.delete(key: _kLogin);
    await _storage.delete(key: _kPassword);
  }
}
