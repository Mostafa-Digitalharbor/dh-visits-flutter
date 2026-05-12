import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/employees_repository.dart';
import '../data/models/employee.dart';

part 'employees_event.dart';
part 'employees_state.dart';

class EmployeesBloc extends Bloc<EmployeesEvent, EmployeesState> {
  final EmployeesRepository repository;

  EmployeesBloc({required this.repository}) : super(const EmployeesState()) {
    on<EmployeesLoadRequested>(_onLoad);
    on<EmployeesSearchChanged>(_onSearch);
  }

  Future<void> _onLoad(
    EmployeesLoadRequested event,
    Emitter<EmployeesState> emit,
  ) async {
    emit(state.copyWith(status: EmployeesStatus.loading));
    try {
      final items = await repository.list(search: state.search);
      emit(state.copyWith(
        status: EmployeesStatus.success,
        items: items,
        error: null,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: EmployeesStatus.failure, error: e));
    }
  }

  Future<void> _onSearch(
    EmployeesSearchChanged event,
    Emitter<EmployeesState> emit,
  ) async {
    emit(state.copyWith(search: event.query));
    add(const EmployeesLoadRequested());
  }
}
