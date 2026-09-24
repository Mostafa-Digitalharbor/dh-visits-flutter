part of 'visits_list_bloc.dart';

sealed class VisitsListEvent extends Equatable {
  const VisitsListEvent();
  @override
  List<Object?> get props => [];
}

/// (Re)load the current scope from the backend.
class VisitsListLoadRequested extends VisitsListEvent {
  /// Optional scope override; defaults to keeping the current scope.
  final VisitListScope? scope;
  const VisitsListLoadRequested({this.scope});
  @override
  List<Object?> get props => [scope];
}

/// Switch tab (mine / pending / team / escalated) and refetch.
class VisitsListScopeChanged extends VisitsListEvent {
  final VisitListScope scope;
  const VisitsListScopeChanged(this.scope);
  @override
  List<Object?> get props => [scope];
}

/// Client-side substring filter; no refetch.
class VisitsListSearchChanged extends VisitsListEvent {
  final String query;
  const VisitsListSearchChanged(this.query);
  @override
  List<Object?> get props => [query];
}

/// Client-side filter on a single workflow state (`null` = all); no refetch.
class VisitsListStateFilterChanged extends VisitsListEvent {
  final VisitState? state;
  const VisitsListStateFilterChanged(this.state);
  @override
  List<Object?> get props => [state];
}

/// Opens the list on a dashboard preset (see [VisitsListFocus]); no refetch.
/// Clears the state filter so the preset alone decides what shows.
class VisitsListFocusChanged extends VisitsListEvent {
  final VisitsListFocus focus;
  const VisitsListFocusChanged(this.focus);
  @override
  List<Object?> get props => [focus];
}

/// A visit changed on this device (an action the user just took, possibly
/// still queued offline). Replaces the row in place, so the list shows the new
/// state without waiting for — or, offline, without being able to make — a
/// round trip. The next reload brings the server's version.
class VisitsListVisitChanged extends VisitsListEvent {
  final Visit visit;
  const VisitsListVisitChanged(this.visit);
  @override
  List<Object?> get props => [visit];
}

/// Drop every user-scoped value back to the initial state. Dispatched on
/// logout: this bloc lives for the whole app, so without it the next user
/// inherits the previous one's items *and* filters — a stale `searchQuery`
/// silently filtered the incoming user's list down to nothing while the
/// (recreated, empty-looking) search field gave no hint why.
class VisitsListReset extends VisitsListEvent {
  const VisitsListReset();
}
