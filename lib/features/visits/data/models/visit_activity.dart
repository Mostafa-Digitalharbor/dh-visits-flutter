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

  factory VisitActivity.fromJson(Map<String, dynamic> json) {
    String? m2oName(dynamic v) =>
        (v is List && v.length >= 2) ? v[1]?.toString() : null;
    final deadlineRaw = json['date_deadline'];
    return VisitActivity(
      id: (json['id'] as num).toInt(),
      summary: (json['summary'] == false || json['summary'] == null)
          ? (m2oName(json['activity_type_id']) ?? '')
          : json['summary'].toString(),
      typeName: m2oName(json['activity_type_id']),
      visitId: (json['res_id'] as num?)?.toInt() ?? 0,
      visitRef: (json['res_name'] == false) ? null : json['res_name']?.toString(),
      deadline: (deadlineRaw == null || deadlineRaw == false)
          ? null
          : DateTime.tryParse(deadlineRaw.toString()),
      urgency: activityUrgencyFromWire(json['state']?.toString()),
    );
  }
}
