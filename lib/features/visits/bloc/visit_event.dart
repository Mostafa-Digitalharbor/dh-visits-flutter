part of 'visit_bloc.dart';

sealed class VisitEvent extends Equatable {
  const VisitEvent();
  @override
  List<Object?> get props => [];
}

/// Start an approved visit (captures GPS, moves it to `in_progress`).
class VisitStartRequested extends VisitEvent {
  final Visit visit;
  const VisitStartRequested({required this.visit});
  @override
  List<Object?> get props => [visit];
}

/// End the running visit (outcome required, captures GPS, moves to `done`).
class VisitEndRequested extends VisitEvent {
  final int visitId;
  final String outcome;
  const VisitEndRequested({required this.visitId, required this.outcome});
  @override
  List<Object?> get props => [visitId, outcome];
}

/// On app/home init, ask the backend for an in-progress visit and rehydrate
/// the persistent bar.
class VisitResumeRequested extends VisitEvent {
  const VisitResumeRequested();
}

class VisitCleared extends VisitEvent {
  const VisitCleared();
}
