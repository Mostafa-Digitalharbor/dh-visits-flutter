part of 'live_location_bloc.dart';

sealed class LiveLocationEvent extends Equatable {
  const LiveLocationEvent();
  @override
  List<Object?> get props => [];
}

class LiveLocationStartRequested extends LiveLocationEvent {
  const LiveLocationStartRequested();
}

class LiveLocationStopRequested extends LiveLocationEvent {
  const LiveLocationStopRequested();
}

class LiveLocationTickRequested extends LiveLocationEvent {
  const LiveLocationTickRequested();
}
