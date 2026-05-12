import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  static const _kUser = 'session_user';

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

  Future<void> clear() async {
    await _storage.delete(key: _kUser);
  }
}
