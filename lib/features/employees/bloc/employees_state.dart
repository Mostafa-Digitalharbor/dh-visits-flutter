part of 'employees_bloc.dart';

class EmployeesState extends SearchableListState<Employee> {
  const EmployeesState({
    super.status,
    super.items,
    super.search,
    super.error,
  });

  @override
  EmployeesState copyWithBase({
    ListStatus? status,
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
}
