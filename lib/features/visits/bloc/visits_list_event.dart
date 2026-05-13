part of 'visits_list_bloc.dart';

sealed class VisitsListEvent extends Equatable {
  const VisitsListEvent();
  @override
  List<Object?> get props => [];
}

class VisitsListLoadRequested extends VisitsListEvent {
  /// True when the request is being made on behalf of an admin — the
  /// repository will also return draft visits in that case so the
  /// manager has visibility over the full pipeline. Defaults to false
  /// for safety (field users keep the trimmed view).
  final bool includeDrafts;
  const VisitsListLoadRequested({this.includeDrafts = false});

  @override
  List<Object?> get props => [includeDrafts];
}

class VisitsListFilterChanged extends VisitsListEvent {
  final VisitsFilter filter;
  const VisitsListFilterChanged(this.filter);
  @override
  List<Object?> get props => [filter];
}

/// Pure client-side filter — does NOT refetch from the server. The page
/// applies `searchQuery` on top of `state.items` when rendering.
class VisitsListSearchChanged extends VisitsListEvent {
  final String query;
  const VisitsListSearchChanged(this.query);
  @override
  List<Object?> get props => [query];
}

/// Admin-only quick filter on lifecycle state. Client-side; no refetch.
class VisitsListStatusFilterChanged extends VisitsListEvent {
  final VisitStatusFilter filter;
  const VisitsListStatusFilterChanged(this.filter);
  @override
  List<Object?> get props => [filter];
}

/// Admin-only quick filter on execution timing (on time / early /
/// overdue). Client-side; no refetch.
class VisitsListTimingFilterChanged extends VisitsListEvent {
  final VisitTimingFilter filter;
  const VisitsListTimingFilterChanged(this.filter);
  @override
  List<Object?> get props => [filter];
}
