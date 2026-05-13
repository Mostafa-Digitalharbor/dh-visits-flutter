part of 'visits_list_bloc.dart';

enum VisitsListStatus { initial, loading, success, failure }

enum VisitsFilter { today, all }

/// Admin-only quick filter on the visit's lifecycle state. Used to slice
/// the "All" view between work that's done and work that isn't yet.
/// `pendingReview` is the admin's actionable bucket — visits the
/// employee finished but the admin hasn't yet approved.
enum VisitStatusFilter { all, completed, pendingReview, incomplete }

/// Admin-only quick filter on whether the visit ran on its scheduled
/// day. `overdue` collapses two cases — a still-pending visit whose
/// scheduled day has passed, and a completed visit whose check-out
/// landed after the scheduled day — both surface here as "past due".
enum VisitTimingFilter { all, onTime, early, overdue }

class VisitsListState extends Equatable {
  final VisitsListStatus status;
  final List<Visit> items;
  final VisitsFilter filter;
  final ApiException? error;

  /// Client-side substring filter on customer name. Empty = show all.
  final String searchQuery;

  /// Admin-only filters on status + timing. Default to `all` so they
  /// have no effect unless explicitly tapped, and they're ignored by
  /// the page unless the logged-in user is a manager.
  final VisitStatusFilter statusFilter;
  final VisitTimingFilter timingFilter;

  const VisitsListState({
    this.status = VisitsListStatus.initial,
    this.items = const [],
    this.filter = VisitsFilter.today,
    this.error,
    this.searchQuery = '',
    this.statusFilter = VisitStatusFilter.all,
    this.timingFilter = VisitTimingFilter.all,
  });

  VisitsListState copyWith({
    VisitsListStatus? status,
    List<Visit>? items,
    VisitsFilter? filter,
    ApiException? error,
    String? searchQuery,
    VisitStatusFilter? statusFilter,
    VisitTimingFilter? timingFilter,
  }) =>
      VisitsListState(
        status: status ?? this.status,
        items: items ?? this.items,
        filter: filter ?? this.filter,
        error: error,
        searchQuery: searchQuery ?? this.searchQuery,
        statusFilter: statusFilter ?? this.statusFilter,
        timingFilter: timingFilter ?? this.timingFilter,
      );

  @override
  List<Object?> get props => [
        status,
        items,
        filter,
        error,
        searchQuery,
        statusFilter,
        timingFilter,
      ];
}
