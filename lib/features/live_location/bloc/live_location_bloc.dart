import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/constants.dart';
import '../../../core/location/location_service.dart';
import '../../../core/utils/distance.dart';
import '../data/live_location_repository.dart';

part 'live_location_event.dart';
part 'live_location_state.dart';

class LiveLocationBloc extends Bloc<LiveLocationEvent, LiveLocationState> {
  final LiveLocationRepository repository;
  final LocationService locationService;
  Timer? _timer;

  LiveLocationBloc({
    required this.repository,
    required this.locationService,
  }) : super(const LiveLocationState()) {
    on<LiveLocationStartRequested>(_onStart);
    on<LiveLocationStopRequested>(_onStop);
    on<LiveLocationTickRequested>(_onTick);
  }

  Future<void> _onStart(
    LiveLocationStartRequested event,
    Emitter<LiveLocationState> emit,
  ) async {
    final ok = await locationService.ensurePermission();
    if (!ok) {
      emit(state.copyWith(
        enabled: false,
        error: ApiException(code: ApiErrorCode.locationPermission),
      ));
      return;
    }
    emit(state.copyWith(enabled: true, error: null));
    _timer?.cancel();
    _timer = Timer.periodic(AppConstants.locationPingInterval, (_) {
      add(const LiveLocationTickRequested());
    });
    add(const LiveLocationTickRequested());
  }

  Future<void> _onStop(
    LiveLocationStopRequested event,
    Emitter<LiveLocationState> emit,
  ) async {
    _timer?.cancel();
    _timer = null;
    emit(state.copyWith(enabled: false));
  }

  Future<void> _onTick(
    LiveLocationTickRequested event,
    Emitter<LiveLocationState> emit,
  ) async {
    if (!state.enabled) return;
    try {
      final pos = await locationService.getCurrent();

      // Throttle: skip the push if the employee barely moved AND we already
      // sent a heartbeat recently. We always send when standing still past
      // the heartbeat interval so the server keeps treating them as online.
      final lastSent = state.lastSent;
      final lastLat = state.lastLat;
      final lastLng = state.lastLng;
      if (lastSent != null && lastLat != null && lastLng != null) {
        final moved =
            haversineMeters(lastLat, lastLng, pos.latitude, pos.longitude);
        final age = DateTime.now().difference(lastSent);
        if (moved < AppConstants.locationMinDistanceMeters &&
            age < AppConstants.locationHeartbeatInterval) {
          return;
        }
      }

      await repository.push(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
      );
      emit(state.copyWith(
        lastSent: DateTime.now(),
        lastLat: pos.latitude,
        lastLng: pos.longitude,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(error: ApiException.unknown(e.toString())));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
