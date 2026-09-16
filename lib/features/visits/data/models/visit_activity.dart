import '../../../../core/api/odoo_parse.dart';

/// A pending to-do assigned to the current user on a visit — the in-app
/// notification feed. Backed by Odoo's standard `mail.activity` (the same
/// records that drive the manager's Activities clock and bell). The
/// `dh_visit_management` module creates these on submit / escalate /
/// participant-approval, targeted at the responsible manager.
enum ActivityUrgency { overdue, today, planned, unknown }

ActivityUrgency activityUrgencyFromWire(String? raw) {
  switch (raw) {
    case 'overdue':
      return ActivityUrgency.overdue;
    case 'today':
      return ActivityUrgency.today;
    case 'planned':
      return ActivityUrgency.planned;
    default:
      return ActivityUrgency.unknown;
  }
}

class VisitActivity {
  final int id;
  final String summary;
  final String? typeName;

  /// The `dh.visit` record this activity is about — used to open its detail.
  final int visitId;
  final String? visitRef;
  final DateTime? deadline;
  final ActivityUrgency urgency;

  const VisitActivity({
    required this.id,
    required this.summary,
    this.typeName,
    required this.visitId,
    this.visitRef,
    this.deadline,
    this.urgency = ActivityUrgency.unknown,
  });

  /// Throws [FormatException] for a row without an id or a visit to open —
  /// an activity the user could tap but never reach — so `parseRows` skips it.
  factory VisitActivity.fromJson(Map<String, dynamic> json) {
    final typeName = odooMany2one(json['activity_type_id']).name;
    return VisitActivity(
      id:
          odooInt(json['id']) ??
          (throw const FormatException('activity row without an id')),
      summary: odooString(json['summary']) ?? typeName ?? '',
      typeName: typeName,
      visitId:
          odooInt(json['res_id']) ??
          (throw const FormatException('activity without a visit')),
      visitRef: odooString(json['res_name']),
      // A date field (`YYYY-MM-DD`), so a plain local-date parse is right.
      deadline: DateTime.tryParse(odooString(json['date_deadline']) ?? ''),
      urgency: activityUrgencyFromWire(odooString(json['state'])),
    );
  }
}
