import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';
import '../utils/app_log.dart';

/// Field names inside the stored user blob that other layers read directly
/// (the offline trackers need the uid without parsing a whole `AuthUser`).
/// `AuthUser.toJson` writes these same keys.
abstract final class SessionUserFields {
  static const uid = 'uid';
  static const username = 'username';
  static const employeeId = 'employee_id';
  static const employeeName = 'employee_name';
}

class SessionStorage {
  static const _kUser = StorageKeys.sessionUser;

  // The sign-in credentials, kept so an expired Odoo session can be renewed
  // without throwing the user back to the login screen mid-visit. Odoo's
  // `/web/session/authenticate` is the only way to mint a new `session_id` for
  // these routes (there is no refresh token), so this is what "re-authenticate
  // and retry once" in docs/API.md requires. Stored only in the platform
  // keystore/keychain via FlutterSecureStorage, never in SharedPreferences,
  // and wiped by [clear] on every logout.
  static const _kLogin = StorageKeys.sessionLogin;
  static const _kPassword = StorageKeys.sessionPassword;

  /// The app's keychain/keystore. On iOS items are readable after the first
  /// unlock since boot (the default is "while unlocked"): an expired session
  /// is renewed — and the signed-in user read — while a visit's trail uploads
  /// with the phone locked in a pocket. `ThisDeviceOnly`: never restored to
  /// another phone from a backup.
  static const FlutterSecureStorage secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final FlutterSecureStorage _storage;

  SessionStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? secureStorage;

  /// Re-writes the stored session under the current accessibility. Items saved
  /// by an earlier version stay readable, but keep their old "while unlocked"
  /// class until written again — so this runs once at start-up, in the
  /// foreground. Never throws.
  Future<void> refreshProtection() async {
    for (final key in const [_kUser, _kLogin, _kPassword]) {
      try {
        final value = await _storage.read(key: key);
        if (value != null) await _storage.write(key: key, value: value);
      } catch (e) {
        appLog('[SessionStorage] could not refresh $key: $e');
      }
    }
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: _kUser, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: _kUser);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  /// The signed-in user's Odoo id, or null when signed out.
  Future<int?> readUid() async {
    final uid = (await getUser())?[SessionUserFields.uid];
    return uid is num ? uid.toInt() : null;
  }

  /// The signed-in user's `hr.employee` id, or null.
  Future<int?> readEmployeeId() async {
    final id = (await getUser())?[SessionUserFields.employeeId];
    return id is num ? id.toInt() : null;
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

  /// Forgets the session and the stored credentials.
  ///
  /// Never throws: each key is deleted on its own, so one keystore error
  /// can't leave the password behind, and a sign-out never gets stuck halfway
  /// (the caller still has to report the user as signed out).
  Future<void> clear() async {
    for (final key in const [_kUser, _kLogin, _kPassword]) {
      try {
        await _storage.delete(key: key);
      } catch (e) {
        appLog('[SessionStorage] could not delete $key: $e');
      }
    }
  }
}
