import 'package:equatable/equatable.dart';

import '../../../../core/api/odoo_parse.dart';
import '../../../../core/storage/session_storage.dart';

/// The user's role inside the `dh_visit_management` module, derived from their
/// Odoo security-group membership (highest wins). Drives which visit screens,
/// list tabs and action buttons the app exposes.
enum VisitRole { none, user, manager, projectManager, admin }

/// Which of the four `dh_visit_management` security groups the signed-in user
/// belongs to, as answered by Odoo's `res.users.has_group`.
///
/// Membership is asked for **by xmlid**, never by `res.groups` row id. Odoo
/// numbers those rows in install order and every company runs its own Odoo, so
/// the id identifying a "visit manager" on one database identifies something
/// unrelated on the next. (Measured on the live test server: the id for
/// `group_visit_project_manager` had already drifted from 43 to 45.)
///
/// `has_group` is also the only portable way to ask. Resolving the xmlids
/// through `ir.model.data` first looks equivalent, but that model is readable
/// only by the *Access Rights* group — so for every ordinary user the lookup
/// raised AccessError, the profile read failed, and the role silently fell back
/// to [VisitRole.none]. Every manager was demoted to a field rep and lost the
/// approval UI. `has_group` runs with elevated rights inside Odoo and answers
/// for any user.
class VisitGroupMemberships {
  final bool user;
  final bool manager;
  final bool projectManager;
  final bool admin;

  const VisitGroupMemberships({
    this.user = false,
    this.manager = false,
    this.projectManager = false,
    this.admin = false,
  });

  /// No membership anywhere — a valid answer (an Odoo user outside the visits
  /// module), not a failed lookup. A lookup that *fails* throws instead, so the
  /// caller can mark the profile incomplete rather than quietly downgrade.
  static const VisitGroupMemberships none = VisitGroupMemberships();

  bool get isEmpty => !user && !manager && !projectManager && !admin;

  /// Highest membership wins.
  VisitRole get role {
    if (admin) return VisitRole.admin;
    if (projectManager) return VisitRole.projectManager;
    if (manager) return VisitRole.manager;
    if (user) return VisitRole.user;
    return VisitRole.none;
  }
}

/// Reads back what [AuthUser.toJson] stored (`VisitRole.name`). Anything
/// unknown — an older build's payload — degrades to [VisitRole.none].
VisitRole _visitRoleFromName(dynamic raw) =>
    VisitRole.values.asNameMap()[odooString(raw)] ?? VisitRole.none;

class AuthUser extends Equatable {
  final int uid;
  final String username;
  final String? employeeName;
  final int? employeeId;
  final int? companyId;

  /// Odoo built-in flag — true for the database administrator.
  final bool isAdmin;

  /// Odoo built-in flag (`is_system`) — true for users in the Settings /
  /// "Administration: Settings" access group. On a vanilla Odoo (no custom
  /// visits module) we treat system/admin users as managers, since there's
  /// no dedicated manager group to key off.
  final bool isSystem;

  /// True when the user should get the manager experience (Customers tab,
  /// editable visits). On vanilla Odoo this is derived from the built-in
  /// `is_admin` / `is_system` flags returned by `session_info`.
  final bool isManager;

  /// IANA timezone of the Odoo user (`res.users.tz`), e.g. `Africa/Cairo`.
  /// Fetched right after login via `call_kw` because the
  /// `session_info`/`authenticate` payload sometimes returns `false`.
  /// All Odoo datetimes are stored in UTC; we use this string to render
  /// them in the user's preferred timezone instead of the device clock.
  final String? tz;

  /// The user's role in the `dh_visit_management` module, derived from their
  /// Odoo security groups right after login (see [AuthRepository.login]).
  final VisitRole visitRole;

  /// True when the post-login profile read failed, so [visitRole], [tz] and
  /// [employeeId] are fallbacks rather than real values.
  ///
  /// This is not cosmetic: with no [employeeId] the visit action bar can't
  /// recognise the user as the visit's owner and every workflow button
  /// disappears. The app must say so rather than look quietly broken.
  final bool profileIncomplete;

  const AuthUser({
    required this.uid,
    required this.username,
    this.employeeName,
    this.employeeId,
    this.companyId,
    this.isAdmin = false,
    this.isSystem = false,
    this.isManager = false,
    this.tz,
    this.visitRole = VisitRole.none,
    this.profileIncomplete = false,
  });

  /// True for any manager-tier visit role (manager / project manager / admin).
  bool get isVisitManager =>
      visitRole == VisitRole.manager ||
      visitRole == VisitRole.projectManager ||
      visitRole == VisitRole.admin;

  /// Whether the user gets the manager experience (Team/Pending tabs, approve
  /// affordances, planning visits for others). Keyed off the visit role, with
  /// the Odoo admin flag as a safety net.
  bool get canEditVisits => isVisitManager || isAdmin;

  /// Can act as an approver on visits routed to them (direct/higher manager,
  /// project manager on escalated visits, admin). The server still enforces
  /// the exact approver rules; this only gates showing the buttons.
  bool get canApproveVisits => isVisitManager || isAdmin;

  /// Project managers and admins additionally see escalated visits.
  bool get canSeeEscalated =>
      visitRole == VisitRole.projectManager || visitRole == VisitRole.admin;

  /// Managers/admins can plan (create) visits on behalf of a subordinate.
  bool get canPlanForOthers => isVisitManager || isAdmin;

  /// Human-friendly name. Falls back to login if employee name unknown.
  String get displayName => employeeName ?? username;

  /// Parses Odoo's `session_info` payload or a stored session.
  ///
  /// Tolerant by design: Odoo sends `false` for an unset field and a
  /// `[id, name]` pair for a many2one, and a bare `as num` cast on either used
  /// to fail a sign-in the server had already accepted. Only a missing uid is
  /// fatal — there is no user without one.
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final uid = odooInt(json[SessionUserFields.uid]);
    if (uid == null) {
      throw const FormatException('Session payload carries no uid');
    }
    final isAdmin = odooBool(json['is_admin']);
    final isSystem = odooBool(json['is_system']);
    return AuthUser(
      uid: uid,
      username: odooString(json[SessionUserFields.username]) ?? '',
      employeeName: odooString(json[SessionUserFields.employeeName]) ??
          odooString(json['name']),
      employeeId: odooMany2one(json[SessionUserFields.employeeId]).id,
      companyId: odooMany2one(json['company_id']).id,
      isAdmin: isAdmin,
      isSystem: isSystem,
      // Vanilla Odoo has no custom manager group. Treat admin/system users
      // as managers. If a server *does* expose `is_manager`, honour it too.
      isManager: odooBool(json['is_manager']) || isAdmin || isSystem,
      tz: odooString(json['tz']),
      visitRole: _visitRoleFromName(json['visit_role']),
      profileIncomplete: odooBool(json['profile_incomplete']),
    );
  }

  /// Whether the app has anything to offer this account: a visit role, or the
  /// Odoo administrator (who sees everything). Meaningless while
  /// [profileIncomplete] — the role is then a fallback, not an answer.
  bool get hasVisitAccess => visitRole != VisitRole.none || isAdmin;

  Map<String, dynamic> toJson() => {
        SessionUserFields.uid: uid,
        SessionUserFields.username: username,
        SessionUserFields.employeeName: employeeName,
        SessionUserFields.employeeId: employeeId,
        'company_id': companyId,
        'is_admin': isAdmin,
        'is_system': isSystem,
        'is_manager': isManager,
        'tz': tz,
        'visit_role': visitRole.name,
        // Persisted: the fallback role is what got saved, so a cold start with
        // this session would otherwise look healthy while still missing every
        // action button.
        'profile_incomplete': profileIncomplete,
      };

  AuthUser copyWith({
    String? tz,
    VisitRole? visitRole,
    int? employeeId,
    bool? profileIncomplete,
  }) =>
      AuthUser(
        uid: uid,
        username: username,
        employeeName: employeeName,
        employeeId: employeeId ?? this.employeeId,
        companyId: companyId,
        isAdmin: isAdmin,
        isSystem: isSystem,
        isManager: isManager,
        tz: tz ?? this.tz,
        visitRole: visitRole ?? this.visitRole,
        profileIncomplete: profileIncomplete ?? this.profileIncomplete,
      );

  @override
  List<Object?> get props => [
        uid,
        username,
        employeeId,
        isAdmin,
        isManager,
        tz,
        visitRole,
        profileIncomplete,
      ];
}
