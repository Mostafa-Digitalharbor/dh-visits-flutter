part of 'create_visit_bloc.dart';

enum CreateVisitStatus { idle, submitting, success, failure }

class CreateVisitState extends Equatable {
  final CreateVisitStatus status;
  final VisitType visitType;
  final LinkedRecord? linked;
  final DateTime? scheduled;
  final String purpose;
  final String location;

  /// Optional subordinate the visit is planned for (managers only). `null`
  /// means the visit is created for the caller.
  final Employee? employee;
  final List<Employee> participants;

  final int? createdVisitId;
  final ApiException? error;

  const CreateVisitState({
    this.status = CreateVisitStatus.idle,
    this.visitType = VisitType.project,
    this.linked,
    this.scheduled,
    this.purpose = '',
    this.location = '',
    this.employee,
    this.participants = const [],
    this.createdVisitId,
    this.error,
  });

  bool get isValid =>
      visitType != VisitType.unknown &&
      linked != null &&
      scheduled != null &&
      purpose.trim().isNotEmpty;

  /// Customer name to display, taken from the chosen project/opportunity.
  String? get customerName => linked?.partnerName;

  CreateVisitState copyWith({
    CreateVisitStatus? status,
    VisitType? visitType,
    LinkedRecord? linked,
    bool clearLinked = false,
    DateTime? scheduled,
    String? purpose,
    String? location,
    Employee? employee,
    bool clearEmployee = false,
    List<Employee>? participants,
    int? createdVisitId,
    ApiException? error,
  }) =>
      CreateVisitState(
        status: status ?? this.status,
        visitType: visitType ?? this.visitType,
        linked: clearLinked ? null : (linked ?? this.linked),
        scheduled: scheduled ?? this.scheduled,
        purpose: purpose ?? this.purpose,
        location: location ?? this.location,
        employee: clearEmployee ? null : (employee ?? this.employee),
        participants: participants ?? this.participants,
        createdVisitId: createdVisitId ?? this.createdVisitId,
        error: error,
      );

  @override
  List<Object?> get props => [
        status,
        visitType,
        linked?.id,
        scheduled,
        purpose,
        location,
        employee?.hrEmployeeId,
        participants.map((e) => e.hrEmployeeId).toList(),
        createdVisitId,
        error,
      ];
}
