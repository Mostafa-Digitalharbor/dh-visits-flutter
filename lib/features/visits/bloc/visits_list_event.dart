part of 'visits_list_bloc.dart';

sealed class VisitsListEvent extends Equatable {
  const VisitsListEvent();
  @override
  List<Object?> get props => [];
}

class VisitsListLoadRequested extends VisitsListEvent {
  const VisitsListLoadRequested();
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
