part of 'visits_list_bloc.dart';

enum VisitsListStatus { initial, loading, success, failure }

/// Which slice of visits the list is showing. `mine` uses the REST `/my`
/// endpoint; the manager scopes use `call_kw` (record rules scope them to the
/// manager's hierarchy).
enum VisitListScope { mine, pending, team, escalated }

class VisitsListState extends Equatable {
  final VisitsListStatus status;
  final List<Visit> items;
  final VisitListScope scope;
  final ApiException? error;

  /// Client-side substring filter on customer / reference / purpose.
  final String searchQuery;

  /// Optional client-side filter on a single workflow state. `null` = all.
  final VisitState? stateFilter;

  const VisitsListState({
    this.status = VisitsListStatus.initial,
    this.items = const [],
    this.scope = VisitListScope.mine,
    this.error,
    this.searchQuery = '',
    this.stateFilter,
  });

  VisitsListState copyWith({
    VisitsListStatus? status,
    List<Visit>? items,
    VisitListScope? scope,
    ApiException? error,
    String? searchQuery,
    VisitState? stateFilter,
    bool clearStateFilter = false,
  }) =>
      VisitsListState(
        status: status ?? this.status,
        items: items ?? this.items,
        scope: scope ?? this.scope,
        error: error,
        searchQuery: searchQuery ?? this.searchQuery,
        stateFilter: clearStateFilter ? null : (stateFilter ?? this.stateFilter),
      );

  @override
  List<Object?> get props =>
      [status, items, scope, error, searchQuery, stateFilter];
}
