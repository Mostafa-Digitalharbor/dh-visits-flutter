part of 'create_visit_bloc.dart';

sealed class CreateVisitEvent extends Equatable {
  const CreateVisitEvent();
  @override
  List<Object?> get props => [];
}

class CreateVisitCustomerSelected extends CreateVisitEvent {
  final Customer customer;
  const CreateVisitCustomerSelected(this.customer);
  @override
  List<Object?> get props => [customer.id];
}

class CreateVisitEmployeeSelected extends CreateVisitEvent {
  final Employee employee;
  const CreateVisitEmployeeSelected(this.employee);
  @override
  List<Object?> get props => [employee.userId];
}

class CreateVisitDateSelected extends CreateVisitEvent {
  final DateTime date;
  const CreateVisitDateSelected(this.date);
  @override
  List<Object?> get props => [date];
}

class CreateVisitTypeSelected extends CreateVisitEvent {
  final int? id;
  final String? name;
  const CreateVisitTypeSelected({this.id, this.name});
  @override
  List<Object?> get props => [id, name];
}

class CreateVisitNotesChanged extends CreateVisitEvent {
  final String notes;
  const CreateVisitNotesChanged(this.notes);
  @override
  List<Object?> get props => [notes];
}

class CreateVisitLifecycleSelected extends CreateVisitEvent {
  final VisitLifecycleState state;
  const CreateVisitLifecycleSelected(this.state);
  @override
  List<Object?> get props => [state];
}

class CreateVisitSubmitted extends CreateVisitEvent {
  const CreateVisitSubmitted();
}

class CreateVisitReset extends CreateVisitEvent {
  const CreateVisitReset();
}
