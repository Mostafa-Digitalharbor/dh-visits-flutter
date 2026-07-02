part of 'create_visit_bloc.dart';

sealed class CreateVisitEvent extends Equatable {
  const CreateVisitEvent();
  @override
  List<Object?> get props => [];
}

class CreateVisitTypeChanged extends CreateVisitEvent {
  final VisitType visitType;
  const CreateVisitTypeChanged(this.visitType);
  @override
  List<Object?> get props => [visitType];
}

/// The chosen project or opportunity (carries the customer to display).
class CreateVisitLinkedSelected extends CreateVisitEvent {
  final LinkedRecord linked;
  const CreateVisitLinkedSelected(this.linked);
  @override
  List<Object?> get props => [linked.id];
}

class CreateVisitScheduleSelected extends CreateVisitEvent {
  final DateTime scheduled;
  const CreateVisitScheduleSelected(this.scheduled);
  @override
  List<Object?> get props => [scheduled];
}

class CreateVisitPurposeChanged extends CreateVisitEvent {
  final String purpose;
  const CreateVisitPurposeChanged(this.purpose);
  @override
  List<Object?> get props => [purpose];
}

class CreateVisitLocationChanged extends CreateVisitEvent {
  final String location;
  const CreateVisitLocationChanged(this.location);
  @override
  List<Object?> get props => [location];
}

/// Optional: a manager planning a visit for a subordinate. `null` = self.
class CreateVisitEmployeeSelected extends CreateVisitEvent {
  final Employee? employee;
  const CreateVisitEmployeeSelected(this.employee);
  @override
  List<Object?> get props => [employee?.hrEmployeeId];
}

class CreateVisitParticipantAdded extends CreateVisitEvent {
  final Employee employee;
  const CreateVisitParticipantAdded(this.employee);
  @override
  List<Object?> get props => [employee.hrEmployeeId];
}

class CreateVisitParticipantRemoved extends CreateVisitEvent {
  final Employee employee;
  const CreateVisitParticipantRemoved(this.employee);
  @override
  List<Object?> get props => [employee.hrEmployeeId];
}

class CreateVisitSubmitted extends CreateVisitEvent {
  const CreateVisitSubmitted();
}

class CreateVisitReset extends CreateVisitEvent {
  const CreateVisitReset();
}
