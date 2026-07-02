part of 'visit_bloc.dart';

/// Lifecycle of the *currently running* visit shown in the persistent bar.
enum VisitStatus { idle, submitting, running, ended }

class VisitState extends Equatable {
  final VisitStatus status;

  /// The visit currently `in_progress` (started, not yet ended), if any.
  final Visit? activeVisit;
  final ApiException? error;

  const VisitState({
    this.status = VisitStatus.idle,
    this.activeVisit,
    this.error,
  });

  VisitState copyWith({
    VisitStatus? status,
    Visit? activeVisit,
    ApiException? error,
  }) =>
      VisitState(
        status: status ?? this.status,
        activeVisit: activeVisit ?? this.activeVisit,
        error: error,
      );

  @override
  List<Object?> get props => [status, activeVisit, error];
}
