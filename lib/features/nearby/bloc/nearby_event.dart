part of 'nearby_bloc.dart';

sealed class NearbyEvent extends Equatable {
  const NearbyEvent();
  @override
  List<Object?> get props => [];
}

class NearbyStarted extends NearbyEvent {
  final int customerId;

  /// Optional cached customer (passed from the detail page via route extra).
  /// When present, the bloc skips the broken `/api/customers/<id>` fetch.
  final Customer? customer;

  final double radius;

  const NearbyStarted({
    required this.customerId,
    this.customer,
    this.radius = AppConstants.defaultRadiusMeters,
  });

  @override
  List<Object?> get props => [customerId, customer, radius];
}

class NearbyRefreshed extends NearbyEvent {
  const NearbyRefreshed();
}

class NearbyStopped extends NearbyEvent {
  const NearbyStopped();
}

class NearbyRadiusChanged extends NearbyEvent {
  final double radius;
  const NearbyRadiusChanged(this.radius);
  @override
  List<Object?> get props => [radius];
}

/// Clear all user-scoped data back to the initial state (dispatched on logout).
class NearbyReset extends NearbyEvent {
  const NearbyReset();
}
