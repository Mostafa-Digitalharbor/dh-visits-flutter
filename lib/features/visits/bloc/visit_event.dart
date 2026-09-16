part of 'visit_bloc.dart';

sealed class VisitEvent extends Equatable {
  const VisitEvent();
  @override
  List<Object?> get props => [];
}

/// On app/home init, ask the backend for an in-progress visit and rehydrate
/// the persistent bar.
class VisitResumeRequested extends VisitEvent {
  const VisitResumeRequested();
}

/// A visit was started from this device — live, or held in the offline queue.
/// Shows the bar straight away instead of asking a server that, offline,
/// cannot answer.
class VisitStarted extends VisitEvent {
  final Visit visit;
  const VisitStarted(this.visit);
  @override
  List<Object?> get props => [visit];
}

/// The running visit ended (or the user signed out): hide the bar.
class VisitCleared extends VisitEvent {
  const VisitCleared();
}
