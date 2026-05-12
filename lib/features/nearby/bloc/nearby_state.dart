part of 'nearby_bloc.dart';

enum NearbyStatus { initial, loading, success, failure }

class NearbyState extends Equatable {
  final NearbyStatus status;
  final int? customerId;
  final Customer? customer;
  final double radius;
  final List<NearbyEmployee> employees;
  final DateTime? lastRefresh;
  final ApiException? error;

  const NearbyState({
    this.status = NearbyStatus.initial,
    this.customerId,
    this.customer,
    this.radius = AppConstants.defaultRadiusMeters,
    this.employees = const [],
    this.lastRefresh,
    this.error,
  });

  NearbyState copyWith({
    NearbyStatus? status,
    int? customerId,
    Customer? customer,
    double? radius,
    List<NearbyEmployee>? employees,
    DateTime? lastRefresh,
    ApiException? error,
  }) =>
      NearbyState(
        status: status ?? this.status,
        customerId: customerId ?? this.customerId,
        customer: customer ?? this.customer,
        radius: radius ?? this.radius,
        employees: employees ?? this.employees,
        lastRefresh: lastRefresh ?? this.lastRefresh,
        error: error,
      );

  @override
  List<Object?> get props => [
        status,
        customerId,
        customer,
        radius,
        employees,
        lastRefresh,
        error,
      ];
}
