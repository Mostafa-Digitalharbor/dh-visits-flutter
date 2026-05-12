part of 'visit_bloc.dart';

enum VisitStatus { idle, submitting, checkedIn, checkedOut }

class VisitState extends Equatable {
  final VisitStatus status;
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
