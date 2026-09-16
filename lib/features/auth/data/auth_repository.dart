import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/odoo_parse.dart';
import '../../../core/api/odoo_rpc.dart';
import '../../../core/config/server_config.dart';
import '../../../core/config/server_config_repository.dart';
import '../../../core/constants.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/app_log.dart';
import 'login_rejection.dart';
import 'models/user.dart';

export 'login_rejection.dart';

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
    dynamic result;
    try {
      result = await _authenticate(db, login, password);
    } on ApiException catch (error) {
      // Odoo.sh changes the numeric suffix in a database name when an expired
      // project is restored. Existing app installs still retain the old name
      // in SharedPreferences, so a perfectly valid review account otherwise
      // fails with "Database not found". When this is a single-database host,
      // discover the replacement, persist it, and retry exactly once.
      if (!_isMissingDatabase(error)) rethrow;
      final detectedDb = await _detectSingleDatabase();
      if (detectedDb == null || detectedDb == db) rethrow;
      final current = serverConfig.read();
      await serverConfig.save(
        ServerConfig(baseUrl: current.baseUrl, database: detectedDb),
      );
      result = await _authenticate(detectedDb, login, password);
    }
    // Never log `result` itself: it is the session payload (session id, user
    // context). debugPrint survives release builds, so that would write live
    // credentials to logcat on every login.
    final payload = await _sessionPayload(result);
    var user = AuthUser.fromJson(payload);

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

    // Only a *successful* profile read can say "no role": when it failed, the
    // role is a fallback and the user is let in with the incomplete-profile
    // notice instead of being turned away for our own read error.
    if (!user.profileIncomplete && !user.hasVisitAccess) {
      await _discardServerSession();
      throw const LoginRejectedException(LoginRejection.noVisitRole);
    }

    // Kept (in the secure keystore only) so an expired session can be renewed
    // by [reauthenticate] instead of logging the rep out mid-visit. Best-effort:
    // a keystore failure costs that convenience, never the login itself.
    try {
      await session.saveCredentials(login: login, password: password);
    } catch (e) {
      appLog('[AuthRepository] could not store credentials for renewal: $e');
    }

    await session.saveUser(user.toJson());
    api.sessionEstablished();
    return user;
  }

  /// The `/web/session/authenticate` answer as a session payload, or the
  /// specific reason it isn't one.
  ///
  /// A refused password never reaches here — Odoo raises `AccessDenied`, which
  /// the client maps to `invalidCredentials`. What does reach here:
  /// * `{"uid": null}` — Odoo's documented answer for an account with
  ///   two-step verification, which only the web login can complete. Reading
  ///   it as "invalid credentials" sent users retyping a correct password.
  /// * anything without a `uid` key — not Odoo's sign-in route talking.
  Future<Map<String, dynamic>> _sessionPayload(dynamic result) async {
    final payload = odooMap(result);
    if (payload == null || !payload.containsKey(SessionUserFields.uid)) {
      throw ApiException(
        code: ApiErrorCode.invalidResponse,
        details: 'authenticate answered without a uid',
      );
    }
    final uid = payload[SessionUserFields.uid];
    if (uid == null) {
      await _discardServerSession();
      throw const LoginRejectedException(LoginRejection.twoFactorRequired);
    }
    if (odooInt(uid) == null) {
      throw ApiException(
        code: ApiErrorCode.invalidResponse,
        details: 'authenticate answered a non-numeric uid',
      );
    }
    return payload;
  }

  /// Ends the half-open session a rejected sign-in left on the server, and
  /// drops its cookie. Best-effort: the rejection is what the user must see.
  Future<void> _discardServerSession() async {
    try {
      await api.jsonRpc(Endpoints.destroySession);
    } catch (e) {
      appLog('[AuthRepository] could not end the rejected session: $e');
    }
    try {
      await cookieJar.deleteAll();
    } catch (e) {
      appLog('[AuthRepository] could not clear cookies: $e');
    }
  }

  Future<dynamic> _authenticate(
    String db,
    String login,
    String password,
  ) =>
      api.jsonRpc(
        Endpoints.authenticate,
        params: {'db': db, 'login': login, 'password': password},
      );

  /// Signs back in with the stored credentials after the server answered
  /// `odoo.http.SessionExpiredException`, so `ApiClient` can retry the refused
  /// call once. Returns whether a fresh session cookie is now in the jar.
  ///
  /// Throws only a transient [ApiException] (the server could not be
  /// reached), which leaves the session as it is. Refuses to "renew" into a
  /// different account: if the credentials now resolve to another uid (the
  /// login was reassigned server-side), the caller must fall through to a real
  /// logout rather than keep showing the previous user's data under someone
  /// else's session.
  Future<bool> reauthenticate() async {
    final creds = await _storedCredentials();
    final int? storedUid;
    try {
      storedUid = await session.readUid();
    } catch (e) {
      appLog('[AuthRepository] signed-in user unreadable: $e');
      return false;
    }
    if (creds == null || storedUid == null) return false;
    final db = serverConfig.read().database ?? AppConstants.database;
    final dynamic result;
    try {
      result = await _authenticate(db, creds.login, creds.password);
    } on ApiException catch (e) {
      // Offline or the server is down: nothing is known about the
      // credentials, so the caller must not sign the user out over it.
      if (e.isTransient) rethrow;
      appLog('[AuthRepository] session renewal refused: ${e.code}');
      return false;
    } catch (e) {
      appLog('[AuthRepository] session renewal failed: $e');
      return false;
    }
    final renewedUid = odooInt(odooMap(result)?[SessionUserFields.uid]);
    if (renewedUid != null && renewedUid == storedUid) return true;
    // The login now opens another account. Its cookie must not be used for a
    // single further call while the sign-out runs.
    try {
      await cookieJar.deleteAll();
    } catch (e) {
      appLog('[AuthRepository] could not clear cookies: $e');
    }
    return false;
  }

  Future<({String login, String password})?> _storedCredentials() async {
    try {
      return await session.readCredentials();
    } catch (e) {
      appLog('[AuthRepository] stored credentials unreadable: $e');
      return null;
    }
  }

  static bool _isMissingDatabase(ApiException error) =>
      error.code == ApiErrorCode.databaseNotFound;

  /// The server's only database, or null when it has several or won't say.
  ///
  /// Never throws. With `list_db = False` Odoo answers this route with
  /// `AccessDenied` — which the client reads as "invalid credentials" — and
  /// letting that escape replaced the real "database not found" with a wrong
  /// password message.
  Future<String?> _detectSingleDatabase() async {
    try {
      final names = odooList(await api.jsonRpc(Endpoints.databaseList))
          .map(odooString)
          .whereType<String>()
          .toList();
      return names.length == 1 ? names.single : null;
    } catch (e) {
      appLog('[AuthRepository] database list unavailable: $e');
      return null;
    }
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
    // Fired together — neither depends on the other, so they share one
    // round-trip instead of stacking two. `Future.wait` rather than two bare
    // futures: if the profile read threw first, the group lookup's own failure
    // would otherwise surface as an unhandled async error.
    final (rows, groups) = await (
      api.readRecords(
        AppConstants.usersModel,
        [uid],
        const ['tz', SessionUserFields.employeeId],
      ),
      _resolveVisitGroups(uid),
    ).wait;
    // No profile row still leaves the group answers authoritative — the role
    // must not be thrown away just because tz/employee_id are missing.
    final row = rows.isEmpty ? const <String, dynamic>{} : rows.first;
    return (
      tz: odooString(row['tz']),
      visitRole: groups.role,
      // A many2one: `[id, name]` or `false`.
      employeeId: odooMany2one(row[SessionUserFields.employeeId]).id,
    );
  }

  Future<AuthUser?> currentUser() async {
    final stored = await session.getUser();
    if (stored == null) return null;
    return AuthUser.fromJson(stored);
  }

  /// Ends the session on the server (best-effort: signing out must work
  /// offline) and then locally.
  Future<void> logout() async {
    try {
      await api.jsonRpc(Endpoints.destroySession);
    } catch (e) {
      appLog('[AuthRepository] server-side logout skipped: $e');
    }
    await clearLocalSession();
  }

  /// Clears the locally stored session and cookies *without* calling the
  /// backend. Used when the user switches to a different company's server —
  /// the previous session belongs to the old host and is meaningless now.
  ///
  /// Never throws, and runs both steps even if the first fails: a keystore
  /// error (common after a device restore) must not leave the user stuck
  /// "signed in" with a sign-out button that does nothing.
  Future<void> clearLocalSession() async {
    try {
      await session.clear();
    } catch (e) {
      appLog('[AuthRepository] could not clear the stored session: $e');
    }
    try {
      await cookieJar.deleteAll();
    } catch (e) {
      appLog('[AuthRepository] could not clear cookies: $e');
    }
  }
}
