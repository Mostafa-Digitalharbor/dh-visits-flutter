part of 'visit_bloc.dart';

/// Lifecycle of the *currently running* visit shown in the persistent bar.
enum VisitStatus { idle, running }

class VisitState extends Equatable {
  final VisitStatus status;

  /// The visit currently `in_progress` (started, not yet ended), if any.
  final Visit? activeVisit;

  const VisitState({this.status = VisitStatus.idle, this.activeVisit});

  const VisitState.running(Visit visit)
    : status = VisitStatus.running,
      activeVisit = visit;

  @override
  List<Object?> get props => [status, activeVisit];
}
