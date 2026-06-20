import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/location/location_service.dart';
import '../../customers/data/models/customer.dart';
import '../data/models/visit.dart';
import '../data/visits_repository.dart';

part 'visit_event.dart';
part 'visit_state.dart';

class VisitBloc extends Bloc<VisitEvent, VisitState> {
  final VisitsRepository repository;
  final LocationService locationService;

  VisitBloc({required this.repository, required this.locationService})
      : super(const VisitState()) {
    on<VisitCheckInRequested>(_onCheckIn);
    on<VisitCheckOutRequested>(_onCheckOut);
    on<VisitResumeRequested>(_onResume);
    on<VisitCleared>((event, emit) => emit(const VisitState()));
  }

  Future<void> _onCheckIn(
    VisitCheckInRequested event,
    Emitter<VisitState> emit,
  ) async {
    // Guard: only one open visit at a time per employee. The backend does
    // NOT enforce this, so if we allow a second check-in both records end up
    // open in the DB. We block it here regardless of which customer is
    // currently checked-in.
    if (state.status == VisitStatus.checkedIn) {
      return;
    }
    emit(state.copyWith(status: VisitStatus.submitting, error: null));
    try {
      final ok = await locationService.ensurePermission();
      if (!ok) {
        emit(state.copyWith(
          status: VisitStatus.idle,
          error: ApiException(code: ApiErrorCode.locationPermission),
        ));
        return;
      }
      final pos = await locationService.getCurrent();
      final visit = await repository.checkIn(
        customerId: event.customer.id,
        latitude: pos.latitude,
        longitude: pos.longitude,
        customerName: event.customer.name,
        customerLat: event.customer.latitude,
        customerLng: event.customer.longitude,
        customerAddress: event.customer.address,
        customerPhone: event.customer.phone ?? event.customer.mobile,
      );
      // Check-in response only carries visit_id/state/check_in_time, so we
      // enrich it locally with the customer the user picked.
      final enriched = visit.copyWith(
        customerId: event.customer.id,
        customerName: event.customer.name,
      );
      emit(state.copyWith(
        status: VisitStatus.checkedIn,
        activeVisit: enriched,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: VisitStatus.idle, error: e));
    } catch (e) {
      emit(state.copyWith(
        status: VisitStatus.idle,
        error: ApiException.unknown(e.toString()),
      ));
    }
  }

  Future<void> _onCheckOut(
    VisitCheckOutRequested event,
    Emitter<VisitState> emit,
  ) async {
    emit(state.copyWith(status: VisitStatus.submitting, error: null));
    try {
      final ok = await locationService.ensurePermission();
      if (!ok) {
        emit(state.copyWith(
          status: VisitStatus.checkedIn,
          error: ApiException(code: ApiErrorCode.locationPermission),
        ));
        return;
      }
      final pos = await locationService.getCurrent();
      final visit = await repository.checkOut(
        visitId: event.visitId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        notes: event.notes,
      );
      // Preserve customer info already carried on activeVisit (check-out
      // response also omits it).
      final prev = state.activeVisit;
      final enriched = prev == null
          ? visit
          : visit.copyWith(
              customerId: prev.customerId,
              customerName: prev.customerName,
            );
      emit(state.copyWith(
        status: VisitStatus.checkedOut,
        activeVisit: enriched,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: VisitStatus.checkedIn, error: e));
    } catch (e) {
      emit(state.copyWith(
        status: VisitStatus.checkedIn,
        error: ApiException.unknown(e.toString()),
      ));
    }
  }

  Future<void> _onResume(
    VisitResumeRequested event,
    Emitter<VisitState> emit,
  ) async {
    // Only attempt recovery when we don't already have an active visit in memory.
    if (state.status == VisitStatus.checkedIn) return;
    try {
      final open = await repository.list(state: 'checked_in');
      if (open.isEmpty) return;
      emit(state.copyWith(
        status: VisitStatus.checkedIn,
        activeVisit: open.first,
      ));
    } on ApiException {
      // Silent — recovery is a best-effort enhancement.
    }
  }
}
