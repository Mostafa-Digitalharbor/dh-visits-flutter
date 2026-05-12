part of 'create_visit_bloc.dart';

enum CreateVisitStatus { idle, submitting, success, failure }

class CreateVisitState extends Equatable {
  final CreateVisitStatus status;
  final Customer? customer;
  final Employee? employee;
  final DateTime? date;
  final int? visitTypeId;
  final String? visitTypeName;
  final String notes;
  final int? createdVisitId;
  final ApiException? error;

  const CreateVisitState({
    this.status = CreateVisitStatus.idle,
    this.customer,
    this.employee,
    this.date,
    this.visitTypeId,
    this.visitTypeName,
    this.notes = '',
    this.createdVisitId,
    this.error,
  });

  bool get isValid =>
      customer != null && employee != null && date != null;

  CreateVisitState copyWith({
    CreateVisitStatus? status,
    Customer? customer,
    Employee? employee,
    DateTime? date,
    int? visitTypeId,
    String? visitTypeName,
    bool clearVisitType = false,
    String? notes,
    int? createdVisitId,
    ApiException? error,
  }) =>
      CreateVisitState(
        status: status ?? this.status,
        customer: customer ?? this.customer,
        employee: employee ?? this.employee,
        date: date ?? this.date,
        visitTypeId: clearVisitType ? null : (visitTypeId ?? this.visitTypeId),
        visitTypeName:
            clearVisitType ? null : (visitTypeName ?? this.visitTypeName),
        notes: notes ?? this.notes,
        createdVisitId: createdVisitId ?? this.createdVisitId,
        error: error,
      );

  @override
  List<Object?> get props => [
        status,
        customer?.id,
        employee?.userId,
        date,
        visitTypeId,
        visitTypeName,
        notes,
        createdVisitId,
        error,
      ];
}
