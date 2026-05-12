part of 'visit_bloc.dart';

sealed class VisitEvent extends Equatable {
  const VisitEvent();
  @override
  List<Object?> get props => [];
}

class VisitCheckInRequested extends VisitEvent {
  final Customer customer;
  const VisitCheckInRequested({required this.customer});
  @override
  List<Object?> get props => [customer];
}

class VisitCheckOutRequested extends VisitEvent {
  final int visitId;
  final String? notes;
  const VisitCheckOutRequested({required this.visitId, this.notes});
  @override
  List<Object?> get props => [visitId, notes];
}

/// On app/home init, ask backend if there is an open visit for this employee
/// and rehydrate the active visit screen.
class VisitResumeRequested extends VisitEvent {
  const VisitResumeRequested();
}

class VisitCleared extends VisitEvent {
  const VisitCleared();
}
