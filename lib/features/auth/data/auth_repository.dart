import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/constants.dart';
import '../../../core/storage/session_storage.dart';
import 'models/user.dart';

class AuthRepository {
  final ApiClient api;
  final SessionStorage session;
  final PersistCookieJar cookieJar;

  AuthRepository({
    required this.api,
    required this.session,
    required this.cookieJar,
  });

  Future<AuthUser> login({
    required String login,
    required String password,
  }) async {
    debugPrint('[debug] AuthRepository.login: db=${AppConstants.database} '
        'url=${AppConstants.baseUrl}${Endpoints.authenticate}');
    final result = await api.jsonRpc(
      Endpoints.authenticate,
      params: {
        'db': AppConstants.database,
        'login': login,
        'password': password,
      },
    );
    debugPrint('[debug] AuthRepository.login: result type=${result.runtimeType} '
        'value=$result');

    if (result is! Map || result['uid'] == null) {
      throw ApiException(code: ApiErrorCode.invalidCredentials);
    }

    var user = AuthUser.fromJson(Map<String, dynamic>.from(result));

    // The session_info payload sometimes returns `tz: false`, so always
    // read it directly from the user model right after login.
    try {
      final tz = await _readUserTz(user.uid);
      if (tz != null) {
        user = user.copyWith(tz: tz);
      }
    } catch (e) {
      debugPrint('[debug] AuthRepository.login: tz fetch failed ($e) — '
          'falling back to device clock');
    }

    await session.saveUser(user.toJson());
    return user;
  }

  /// Reads `res.users.tz` for the given uid via Odoo's `call_kw`.
  /// Returns `null` if the field is unset (Odoo serialises it as `false`).
  Future<String?> _readUserTz(int uid) async {
    final result = await api.jsonRpc(
      '/web/dataset/call_kw',
      params: {
        'model': 'res.users',
        'method': 'read',
        'args': [
          [uid],
          ['tz'],
        ],
        'kwargs': {},
      },
    );
    if (result is! List || result.isEmpty) return null;
    final row = result.first;
    if (row is! Map) return null;
    final raw = row['tz'];
    if (raw == null || raw == false) return null;
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'false') return null;
    return s;
  }

  Future<AuthUser?> currentUser() async {
    final stored = await session.getUser();
    if (stored == null) return null;
    return AuthUser.fromJson(stored);
  }

  Future<void> logout() async {
    try {
      await api.jsonRpc(Endpoints.destroySession);
    } catch (_) {
      // ignore network errors during logout
    }
    await session.clear();
    await cookieJar.deleteAll();
  }
}
