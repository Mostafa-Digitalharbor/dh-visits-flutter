import '../../../core/api/api_exceptions.dart';
import '../../../shared/bloc/searchable_list_bloc.dart';
import '../data/employees_repository.dart';
import '../data/models/employee.dart';

part 'employees_state.dart';

/// Employee list + search. All of the load / search / reset machinery lives in
/// [SearchableListBloc]; this only binds it to the repository call.
class EmployeesBloc extends SearchableListBloc<Employee, EmployeesState> {
  EmployeesBloc({required EmployeesRepository repository})
      : super(
          loader: repository.list,
          initialState: const EmployeesState(),
        );
}
