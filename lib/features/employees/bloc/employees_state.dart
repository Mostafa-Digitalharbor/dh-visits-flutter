part of 'employees_bloc.dart';

enum EmployeesStatus { initial, loading, success, failure }

class EmployeesState extends Equatable {
  final EmployeesStatus status;
  final List<Employee> items;
  final String? search;
  final ApiException? error;

  const EmployeesState({
    this.status = EmployeesStatus.initial,
    this.items = const [],
    this.search,
    this.error,
  });

  EmployeesState copyWith({
    EmployeesStatus? status,
    List<Employee>? items,
    String? search,
    ApiException? error,
  }) =>
      EmployeesState(
        status: status ?? this.status,
        items: items ?? this.items,
        search: search ?? this.search,
        error: error,
      );

  @override
  List<Object?> get props => [status, items, search, error];
}
