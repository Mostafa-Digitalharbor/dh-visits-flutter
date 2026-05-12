import 'package:equatable/equatable.dart';

/// Represents a `res.users` record that can receive Customer Visits — i.e.
/// users that are members of the `dh_customer_visits.group_customer_visit_user`
/// (or Manager) group. The mobile assigns visits via the visit's
/// `salesperson_id` field, which points to `res.users`. We call them
/// "employees" only for UX clarity.
class Employee extends Equatable {
  /// The `res.users.id` — this is what we pass as `salesperson_id` when
  /// creating a visit.
  final int userId;
  final String name;
  final String? login;

  /// `res.users.employee_id` — the linked `hr.employee` record id, if any.
  /// Display-only.
  final int? hrEmployeeId;
  final String? hrEmployeeName;

  const Employee({
    required this.userId,
    required this.name,
    this.login,
    this.hrEmployeeId,
    this.hrEmployeeName,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    final empRaw = json['employee_id'];
    int? empId;
    String? empName;
    if (empRaw is List && empRaw.length >= 2) {
      empId = (empRaw[0] as num?)?.toInt();
      empName = empRaw[1]?.toString();
    }
    return Employee(
      userId: (json['id'] as num).toInt(),
      name: (json['name'] ?? json['login'] ?? '').toString(),
      login: json['login']?.toString(),
      hrEmployeeId: empId,
      hrEmployeeName: empName,
    );
  }

  @override
  List<Object?> get props => [userId, name, login, hrEmployeeId];
}
