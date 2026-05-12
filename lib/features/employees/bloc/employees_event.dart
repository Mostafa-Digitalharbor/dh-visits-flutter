part of 'employees_bloc.dart';

sealed class EmployeesEvent extends Equatable {
  const EmployeesEvent();
  @override
  List<Object?> get props => [];
}

class EmployeesLoadRequested extends EmployeesEvent {
  const EmployeesLoadRequested();
}

class EmployeesSearchChanged extends EmployeesEvent {
  final String query;
  const EmployeesSearchChanged(this.query);
  @override
  List<Object?> get props => [query];
}
