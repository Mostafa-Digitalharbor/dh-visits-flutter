import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/odoo_rpc.dart';
import '../../../core/config/server_config_repository.dart';
import '../../../core/constants.dart';
import '../../../core/storage/session_storage.dart';
import 'models/user.dart';

class AuthRepository {
  final ApiClient api;
  final SessionStorage session;
  final PersistCookieJar cookieJar;
  final ServerConfigRepository serverConfig;

  AuthRepository({
    required this.api,
    required this.session,
    required this.cookieJar,
    required this.serverConfig,
  });

  Future<AuthUser> login({
    required String login,
    required String password,
  }) async {
    // Database is taken from the user's per-company server config; fall back to
    // the build-time default for dev/CI builds that ship one.
    final db = serverConfig.read().database ?? AppConstants.database;
    debugPrint('[debug] AuthRepository.login: db=$db '
        'url=${api.baseUrl}${Endpoints.authenticate}');
    final result = await api.jsonRpc(
      Endpoints.authenticate,
      params: {
        'db': db,
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

    // The session_info payload doesn't carry the tz (sometimes `false`) nor the
    // visit security groups, so read both directly from the user model right
    // after login in a single `call_kw`.
    try {
      final profile = await _readUserProfile(user.uid);
      user = user.copyWith(
        tz: profile.tz,
        visitRole: profile.visitRole,
        employeeId: profile.employeeId,
        profileIncomplete: false,
      );
    } catch (e) {
      // Login itself succeeded, so don't block it — but flag the gap. Without
      // employeeId the action bar can't match the user to their own visits and
      // every workflow button vanishes; without tz, visits get stamped against
      // the device clock. The UI surfaces this instead of looking broken.
      debugPrint('[debug] AuthRepository.login: profile fetch failed ($e) — '
          'falling back to device clock / no visit role');
      user = user.copyWith(profileIncomplete: true);
    }

    await session.saveUser(user.toJson());
    return user;
  }

  /// Reads `res.users.tz` + `group_ids` for the given uid via `call_kw` and
  /// derives the visit role. `tz` is `null` when unset (Odoo serialises `false`).
  Future<({String? tz, VisitRole visitRole, int? employeeId})> _readUserProfile(
      int uid) async {
    final rows = await api.readRecords(
      AppConstants.usersModel,
      [uid],
      const ['tz', 'group_ids', 'employee_id'],
    );
    if (rows.isEmpty) {
      return (tz: null, visitRole: VisitRole.none, employeeId: null);
    }
    final row = rows.first;

    String? tz;
    final rawTz = row['tz'];
    if (rawTz != null && rawTz != false) {
      final s = rawTz.toString().trim();
      if (s.isNotEmpty && s != 'false') tz = s;
    }

    final groupIds = (row['group_ids'] is List)
        ? (row['group_ids'] as List).whereType<num>().map((n) => n.toInt())
        : const <int>[];

    // `employee_id` on res.users is a many2one → `[id, name]` or `false`.
    int? employeeId;
    final emp = row['employee_id'];
    if (emp is List && emp.isNotEmpty && emp.first is num) {
      employeeId = (emp.first as num).toInt();
    }

    return (
      tz: tz,
      visitRole: visitRoleFromGroupIds(groupIds),
      employeeId: employeeId,
    );
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

  /// Clears the locally stored session and cookies *without* calling the
  /// backend. Used when the user switches to a different company's server —
  /// the previous session belongs to the old host and is meaningless now.
  Future<void> clearLocalSession() async {
    await session.clear();
    await cookieJar.deleteAll();
  }
}
