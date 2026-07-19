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

class VisitCleared extends VisitEvent {
  const VisitCleared();
}
