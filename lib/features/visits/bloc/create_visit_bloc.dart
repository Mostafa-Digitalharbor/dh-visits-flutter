import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../employees/data/models/employee.dart';
import '../data/models/visit.dart';
import '../data/visits_repository.dart';

part 'create_visit_event.dart';
part 'create_visit_state.dart';

/// Drives the create-visit form. A visit is tied to a project or opportunity
/// (the customer auto-fills server-side). Managers may plan a visit for a
/// subordinate and pre-add participants; the visit is created in `draft` and
/// submitted for approval from the detail screen.
class CreateVisitBloc extends Bloc<CreateVisitEvent, CreateVisitState> {
  final VisitsRepository repository;

  CreateVisitBloc({required this.repository})
    : super(const CreateVisitState()) {
    on<CreateVisitTypeChanged>(_onType);
    on<CreateVisitLinkedSelected>(_onLinked);
    on<CreateVisitScheduleSelected>(_onSchedule);
    on<CreateVisitPurposeChanged>(_onPurpose);
    on<CreateVisitLocationChanged>(_onLocation);
    on<CreateVisitEmployeeSelected>(_onEmployee);
    on<CreateVisitParticipantAdded>(_onParticipantAdded);
    on<CreateVisitParticipantRemoved>(_onParticipantRemoved);
    // Dropped, not queued: a double tap must never file two visits.
    on<CreateVisitSubmitted>(_onSubmit, transformer: droppable());
    on<CreateVisitReset>((e, emit) => emit(const CreateVisitState()));
  }

  // The visit's own fields are frozen once it exists on the server: a retry
  // after a participant failure only adds participants, so an edit here would
  // silently never be saved.

  void _onType(CreateVisitTypeChanged e, Emitter<CreateVisitState> emit) {
    if (state.isCreated) return;
    // Switching type invalidates the linked record (different picker source).
    emit(state.copyWith(visitType: e.visitType, clearLinked: true));
  }

  void _onLinked(CreateVisitLinkedSelected e, Emitter<CreateVisitState> emit) {
    if (state.isCreated) return;
    emit(state.copyWith(linked: e.linked));
  }

  void _onSchedule(
    CreateVisitScheduleSelected e,
    Emitter<CreateVisitState> emit,
  ) {
    if (state.isCreated) return;
    emit(state.copyWith(scheduled: e.scheduled));
  }

  void _onPurpose(CreateVisitPurposeChanged e, Emitter<CreateVisitState> emit) {
    if (state.isCreated) return;
    emit(state.copyWith(purpose: e.purpose));
  }

  void _onLocation(
    CreateVisitLocationChanged e,
    Emitter<CreateVisitState> emit,
  ) {
    if (state.isCreated) return;
    emit(state.copyWith(location: e.location));
  }

  void _onEmployee(
    CreateVisitEmployeeSelected e,
    Emitter<CreateVisitState> emit,
  ) {
    if (state.isCreated) return;
    emit(
      state.copyWith(employee: e.employee, clearEmployee: e.employee == null),
    );
  }

  void _onParticipantAdded(
    CreateVisitParticipantAdded e,
    Emitter<CreateVisitState> emit,
  ) {
    if (state.participants.any(
      (p) => p.hrEmployeeId == e.employee.hrEmployeeId,
    )) {
      return;
    }
    emit(state.copyWith(participants: [...state.participants, e.employee]));
  }

  void _onParticipantRemoved(
    CreateVisitParticipantRemoved e,
    Emitter<CreateVisitState> emit,
  ) {
    emit(
      state.copyWith(
        participants: state.participants
            .where((p) => p.hrEmployeeId != e.employee.hrEmployeeId)
            .toList(),
      ),
    );
  }

  Future<void> _onSubmit(
    CreateVisitSubmitted e,
    Emitter<CreateVisitState> emit,
  ) async {
    if (!state.isValid) return;
    emit(state.copyWith(status: CreateVisitStatus.submitting));
    try {
      var visitId = state.createdVisitId;
      if (visitId == null) {
        visitId = (await repository.createVisit(_values())).id;
        // Recorded before the participants go out. When adding them failed,
        // the form used to report the whole submit as failed; the user tapped
        // again and a second visit was filed against the same customer.
        emit(state.copyWith(createdVisitId: visitId));
      }

      final participantEmpIds = state.participants
          .map((p) => p.hrEmployeeId)
          .whereType<int>()
          .toList();
      if (participantEmpIds.isNotEmpty) {
        await repository.addParticipants(visitId, participantEmpIds);
      }

      emit(state.copyWith(status: CreateVisitStatus.success));
    } catch (e) {
      emit(
        state.copyWith(
          status: CreateVisitStatus.failure,
          error: e is ApiException ? e : ApiException.unexpected(e),
        ),
      );
    }
  }

  /// The `/api/visit/create` payload for the form as it stands.
  Map<String, dynamic> _values() {
    final location = state.location.trim();
    final employeeId = state.employee?.hrEmployeeId;
    return {
      'visit_type': visitTypeToWire(state.visitType),
      if (state.visitType == VisitType.project)
        'project_id': state.linked!.id
      else
        'opportunity_id': state.linked!.id,
      'scheduled_datetime': VisitsRepository.formatOdooUtc(state.scheduled!),
      'purpose': state.purpose.trim(),
      if (location.isNotEmpty) 'location': location,
      if (employeeId != null) 'employee_id': employeeId,
    };
  }
}
