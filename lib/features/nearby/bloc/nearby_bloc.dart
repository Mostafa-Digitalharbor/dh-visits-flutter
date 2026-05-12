import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/constants.dart';
import '../../customers/data/customers_repository.dart';
import '../../customers/data/models/customer.dart';
import '../data/models/nearby_employee.dart';
import '../data/nearby_repository.dart';

part 'nearby_event.dart';
part 'nearby_state.dart';

class NearbyBloc extends Bloc<NearbyEvent, NearbyState> {
  final NearbyRepository nearbyRepository;
  final CustomersRepository customersRepository;
  Timer? _timer;

  NearbyBloc({
    required this.nearbyRepository,
    required this.customersRepository,
  }) : super(const NearbyState()) {
    on<NearbyStarted>(_onStarted);
    on<NearbyRefreshed>(_onRefreshed);
    on<NearbyStopped>(_onStopped);
    on<NearbyRadiusChanged>(_onRadiusChanged);
  }

  Future<void> _onStarted(
    NearbyStarted event,
    Emitter<NearbyState> emit,
  ) async {
    emit(state.copyWith(
      status: NearbyStatus.loading,
      customerId: event.customerId,
      radius: event.radius,
    ));

    // If the detail page already gave us the Customer via route extra, use it
    // immediately and skip the (currently broken) /api/customers/<id> fetch.
    if (event.customer != null) {
      emit(state.copyWith(customer: event.customer));
      await _load(emit);
    } else {
      try {
        final customer = await customersRepository.getById(event.customerId);
        emit(state.copyWith(customer: customer));
        await _load(emit);
      } on ApiException catch (e) {
        emit(state.copyWith(status: NearbyStatus.failure, error: e));
        return;
      }
    }

    _timer?.cancel();
    _timer = Timer.periodic(AppConstants.nearbyRefreshInterval, (_) {
      add(const NearbyRefreshed());
    });
  }

  Future<void> _onRefreshed(
    NearbyRefreshed event,
    Emitter<NearbyState> emit,
  ) async {
    if (state.customerId == null) return;
    await _load(emit);
  }

  Future<void> _onStopped(
    NearbyStopped event,
    Emitter<NearbyState> emit,
  ) async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _onRadiusChanged(
    NearbyRadiusChanged event,
    Emitter<NearbyState> emit,
  ) async {
    emit(state.copyWith(radius: event.radius));
    if (state.customerId != null) {
      await _load(emit);
    }
  }

  Future<void> _load(Emitter<NearbyState> emit) async {
    try {
      final items = await nearbyRepository.fetch(
        customerId: state.customerId!,
        radius: state.radius,
      );
      emit(state.copyWith(
        status: NearbyStatus.success,
        employees: items,
        error: null,
        lastRefresh: DateTime.now(),
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
          status: NearbyStatus.failure, error: e));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
