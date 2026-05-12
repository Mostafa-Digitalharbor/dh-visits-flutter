part of 'live_location_bloc.dart';

class LiveLocationState extends Equatable {
  final bool enabled;
  final DateTime? lastSent;
  final double? lastLat;
  final double? lastLng;
  final ApiException? error;

  const LiveLocationState({
    this.enabled = false,
    this.lastSent,
    this.lastLat,
    this.lastLng,
    this.error,
  });

  LiveLocationState copyWith({
    bool? enabled,
    DateTime? lastSent,
    double? lastLat,
    double? lastLng,
    ApiException? error,
  }) =>
      LiveLocationState(
        enabled: enabled ?? this.enabled,
        lastSent: lastSent ?? this.lastSent,
        lastLat: lastLat ?? this.lastLat,
        lastLng: lastLng ?? this.lastLng,
        error: error,
      );

  @override
  List<Object?> get props => [enabled, lastSent, lastLat, lastLng, error];
}
