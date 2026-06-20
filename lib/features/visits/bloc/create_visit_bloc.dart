import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../customers/data/models/customer.dart';
import '../../employees/data/models/employee.dart';
import '../data/models/visit.dart';
import '../data/visits_repository.dart';

part 'create_visit_event.dart';
part 'create_visit_state.dart';

class CreateVisitBloc extends Bloc<CreateVisitEvent, CreateVisitState> {
  final VisitsRepository repository;

  CreateVisitBloc({required this.repository}) : super(const CreateVisitState()) {
    on<CreateVisitCustomerSelected>(_onCustomerSelected);
    on<CreateVisitEmployeeSelected>(_onEmployeeSelected);
    on<CreateVisitDateSelected>(_onDateSelected);
    on<CreateVisitTypeSelected>(_onTypeSelected);
    on<CreateVisitNotesChanged>(_onNotesChanged);
    on<CreateVisitLifecycleSelected>(_onLifecycleSelected);
    on<CreateVisitSubmitted>(_onSubmit);
    on<CreateVisitReset>(_onReset);
  }

  void _onLifecycleSelected(
      CreateVisitLifecycleSelected event, Emitter<CreateVisitState> emit) {
    emit(state.copyWith(lifecycleState: event.state));
  }

  void _onCustomerSelected(
      CreateVisitCustomerSelected event, Emitter<CreateVisitState> emit) {
    emit(state.copyWith(customer: event.customer));
  }

  void _onEmployeeSelected(
      CreateVisitEmployeeSelected event, Emitter<CreateVisitState> emit) {
    emit(state.copyWith(employee: event.employee));
  }

  void _onDateSelected(
      CreateVisitDateSelected event, Emitter<CreateVisitState> emit) {
    emit(state.copyWith(date: event.date));
  }

  void _onTypeSelected(
      CreateVisitTypeSelected event, Emitter<CreateVisitState> emit) {
    emit(state.copyWith(
      visitTypeId: event.id,
      visitTypeName: event.name,
      clearVisitType: event.id == null,
    ));
  }

  void _onNotesChanged(
      CreateVisitNotesChanged event, Emitter<CreateVisitState> emit) {
    emit(state.copyWith(notes: event.notes));
  }

  void _onReset(CreateVisitReset event, Emitter<CreateVisitState> emit) {
    emit(const CreateVisitState());
  }

  Future<void> _onSubmit(
      CreateVisitSubmitted event, Emitter<CreateVisitState> emit) async {
    if (state.customer == null ||
        state.employee == null ||
        state.date == null) {
      return;
    }
    emit(state.copyWith(status: CreateVisitStatus.submitting, error: null));
    try {
      final id = await repository.create(
        customerId: state.customer!.id,
        salespersonUserId: state.employee!.userId,
        visitDate: state.date!,
        visitTypeId: state.visitTypeId,
        visitTypeName: state.visitTypeName,
        customerName: state.customer!.name,
        customerLat: state.customer!.latitude,
        customerLng: state.customer!.longitude,
        customerAddress: state.customer!.address,
        customerPhone: state.customer!.phone ?? state.customer!.mobile,
        description: state.notes,
        state: state.lifecycleState,
      );
      emit(state.copyWith(
        status: CreateVisitStatus.success,
        createdVisitId: id,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: CreateVisitStatus.failure, error: e));
    } catch (e) {
      emit(state.copyWith(
        status: CreateVisitStatus.failure,
        error: ApiException.unknown(e.toString()),
      ));
    }
  }
}
