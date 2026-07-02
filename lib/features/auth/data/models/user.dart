import 'package:equatable/equatable.dart';

import '../../../../core/constants.dart';

/// The user's role inside the `dh_visit_management` module, derived from their
/// Odoo security-group membership (highest wins). Drives which visit screens,
/// list tabs and action buttons the app exposes.
enum VisitRole { none, user, manager, projectManager, admin }

/// Maps a user's `res.users.group_ids` onto a [VisitRole] (highest match wins).
VisitRole visitRoleFromGroupIds(Iterable<int> groupIds) {
  final ids = groupIds.toSet();
  if (ids.contains(AppConstants.groupVisitAdminId)) return VisitRole.admin;
  if (ids.contains(AppConstants.groupVisitProjectManagerId)) {
    return VisitRole.projectManager;
  }
  if (ids.contains(AppConstants.groupVisitManagerId)) return VisitRole.manager;
  if (ids.contains(AppConstants.groupVisitUserId)) return VisitRole.user;
  return VisitRole.none;
}

VisitRole _visitRoleFromName(dynamic raw) {
  switch (raw?.toString()) {
    case 'admin':
      return VisitRole.admin;
    case 'projectManager':
      return VisitRole.projectManager;
    case 'manager':
      return VisitRole.manager;
    case 'user':
      return VisitRole.user;
    default:
      return VisitRole.none;
  }
}

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

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final isAdmin = json['is_admin'] == true;
    final isSystem = json['is_system'] == true;
    return AuthUser(
      uid: (json['uid'] as num).toInt(),
      username: (json['username'] ?? '').toString(),
      employeeName: (json['employee_name'] ?? json['name'])?.toString(),
      employeeId: (json['employee_id'] as num?)?.toInt(),
      companyId: (json['company_id'] as num?)?.toInt(),
      isAdmin: isAdmin,
      isSystem: isSystem,
      // Vanilla Odoo has no custom manager group. Treat admin/system users
      // as managers. If a server *does* expose `is_manager`, honour it too.
      isManager: json['is_manager'] == true || isAdmin || isSystem,
      tz: _parseTz(json['tz']),
      visitRole: _visitRoleFromName(json['visit_role']),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'username': username,
        'employee_name': employeeName,
        'employee_id': employeeId,
        'company_id': companyId,
        'is_admin': isAdmin,
        'is_system': isSystem,
        'is_manager': isManager,
        'tz': tz,
        'visit_role': visitRole.name,
      };

  AuthUser copyWith({String? tz, VisitRole? visitRole}) => AuthUser(
        uid: uid,
        username: username,
        employeeName: employeeName,
        employeeId: employeeId,
        companyId: companyId,
        isAdmin: isAdmin,
        isSystem: isSystem,
        isManager: isManager,
        tz: tz ?? this.tz,
        visitRole: visitRole ?? this.visitRole,
      );

  static String? _parseTz(dynamic raw) {
    if (raw == null || raw == false) return null;
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'false') return null;
    return s;
  }

  @override
  List<Object?> get props =>
      [uid, username, employeeId, isAdmin, isManager, tz, visitRole];
}
