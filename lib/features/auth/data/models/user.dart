import 'package:equatable/equatable.dart';

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
  });

  /// Combined gate used across the UI to decide whether to expose edit
  /// affordances and the manager-only screens (Customers, full Settings).
  bool get canEditVisits => isManager || isAdmin;

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
      };

  AuthUser copyWith({String? tz}) => AuthUser(
        uid: uid,
        username: username,
        employeeName: employeeName,
        employeeId: employeeId,
        companyId: companyId,
        isAdmin: isAdmin,
        isSystem: isSystem,
        isManager: isManager,
        tz: tz ?? this.tz,
      );

  static String? _parseTz(dynamic raw) {
    if (raw == null || raw == false) return null;
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'false') return null;
    return s;
  }

  @override
  List<Object?> get props =>
      [uid, username, employeeId, isAdmin, isManager, tz];
}
