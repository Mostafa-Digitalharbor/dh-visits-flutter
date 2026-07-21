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
import '../../../core/utils/app_log.dart';

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
    if (kDebugMode) {
      appLog('[debug] AuthRepository.login: db=$db '
          'url=${api.baseUrl}${Endpoints.authenticate}');
    }
    final result = await api.jsonRpc(
      Endpoints.authenticate,
      params: {
        'db': db,
        'login': login,
        'password': password,
      },
    );
    // Never log `result` itself: it is the session payload (session id, user
    // context). debugPrint survives release builds, so that would write live
    // credentials to logcat on every login.
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
      if (kDebugMode) {
        appLog('[debug] AuthRepository.login: profile fetch failed ($e) — '
            'falling back to device clock / no visit role');
      }
      user = user.copyWith(profileIncomplete: true);
    }

    await session.saveUser(user.toJson());
    return user;
  }

  /// Asks Odoo whether [uid] is in one specific `dh_visit_management` group.
  ///
  /// `res.users.has_group` takes the **xmlid**, so nothing per-database is
  /// hardcoded, and it runs with elevated rights inside Odoo so an ordinary
  /// salesperson can ask about their own membership.
  Future<bool> _hasGroup(int uid, String recordName) async {
    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.usersModel,
        'method': 'has_group',
        'args': [
          [uid],
          '${AppConstants.visitGroupModule}.$recordName',
        ],
        'kwargs': const {},
      },
    );
    return result == true;
  }

  /// Resolves the user's visit-group memberships.
  ///
  /// The four questions are asked concurrently, so this costs one round-trip of
  /// latency rather than four.
  ///
  /// This deliberately does NOT go through `ir.model.data` to turn the xmlids
  /// into `res.groups` ids first. That model is readable only by the *Access
  /// Rights* group, so for every ordinary user the lookup raised AccessError,
  /// the whole profile read failed, and the role fell back to
  /// [VisitRole.none] — silently demoting every manager to a field rep with no
  /// approval buttons. Verified against the live server: `ir.model.data` is
  /// denied for all three test accounts, while `has_group` answers for each.
  Future<VisitGroupMemberships> _resolveVisitGroups(int uid) async {
    final results = await Future.wait([
      _hasGroup(uid, AppConstants.groupVisitUserXmlName),
      _hasGroup(uid, AppConstants.groupVisitManagerXmlName),
      _hasGroup(uid, AppConstants.groupVisitProjectManagerXmlName),
      _hasGroup(uid, AppConstants.groupVisitAdminXmlName),
    ]);
    return VisitGroupMemberships(
      user: results[0],
      manager: results[1],
      projectManager: results[2],
      admin: results[3],
    );
  }

  /// Reads `res.users.tz` + `employee_id` for the given uid via `call_kw` and
  /// derives the visit role. `tz` is `null` when unset (Odoo serialises `false`).
  Future<({String? tz, VisitRole visitRole, int? employeeId})> _readUserProfile(
      int uid) async {
    // Fired alongside the profile read rather than before it — neither depends
    // on the other, so they share one round-trip instead of stacking two.
    final groupsFuture = _resolveVisitGroups(uid);
    final rows = await api.readRecords(
      AppConstants.usersModel,
      [uid],
      const ['tz', 'employee_id'],
    );
    final groups = await groupsFuture;
    if (rows.isEmpty) {
      // No profile row, but the group answers are still authoritative — the
      // role must not be thrown away just because tz/employee_id are missing.
      return (tz: null, visitRole: groups.role, employeeId: null);
    }
    final row = rows.first;

    String? tz;
    final rawTz = row['tz'];
    if (rawTz != null && rawTz != false) {
      final s = rawTz.toString().trim();
      if (s.isNotEmpty && s != 'false') tz = s;
    }

    // `employee_id` on res.users is a many2one → `[id, name]` or `false`.
    int? employeeId;
    final emp = row['employee_id'];
    if (emp is List && emp.isNotEmpty && emp.first is num) {
      employeeId = (emp.first as num).toInt();
    }

    return (tz: tz, visitRole: groups.role, employeeId: employeeId);
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
